-- =============================================================================
-- FILE: sql/13_agent_failure_log.sql
-- PURPOSE: The project's "self-improvement mechanism" data trail.
--
--   This is NOT model fine-tuning or retraining — that's explicitly out of
--   scope. It is a durable log of every failed tool call, failed slot-fill
--   (a deterministic gate rejected the model's attempt), and detected user
--   correction, written with enough context for a HUMAN to review later and
--   decide whether a prompt or gate needs updating.
--
--   retry_attempted / retry_corrected_args / retry_succeeded capture the ONE
--   in-conversation retry the agent makes for failures that look fixable
--   without asking the user (see agents/self_improvement.py) — so this table
--   also doubles as the evidence for "how often did the single retry recover
--   a failure automatically" in the FYP report.
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.agent_failure_log (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id         UUID        REFERENCES public.ai_conversations(id) ON DELETE SET NULL,

    -- 'tool_call_error'    → a downstream service/network call raised an exception
    -- 'slot_fill_failure'  → a deterministic gate rejected the model's tool call
    --                        (missing/invalid date, party size, transfer address,
    --                        an invented booking, an unresolved city, ...)
    -- 'user_correction'    → the user's message reads like a correction of a
    --                        prior agent turn (heuristic detector, logged only —
    --                        never auto-acted on, since only the user knows the
    --                        actual correction)
    failure_type            TEXT        NOT NULL
                            CHECK (failure_type IN (
                                'tool_call_error',
                                'slot_fill_failure',
                                'user_correction'
                            )),

    tool_name               TEXT,                           -- NULL for user_correction rows
    tool_args               JSONB,                           -- the args that were attempted
    error_detail            TEXT,                            -- the error/gate message (truncated)

    user_message            TEXT        NOT NULL,            -- the turn that surfaced this (truncated)
    assistant_message       TEXT,                            -- prior assistant turn being corrected
                                                              -- (user_correction rows only)

    -- The single in-conversation retry (see agents/self_improvement.py). All
    -- three stay at their defaults when the failure wasn't safely fixable
    -- without asking the user — that's the common case, not a bug.
    retry_attempted         BOOLEAN     NOT NULL DEFAULT FALSE,
    retry_corrected_args    JSONB,
    retry_succeeded         BOOLEAN,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_failure_log_user_id
    ON public.agent_failure_log(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_failure_log_conversation_id
    ON public.agent_failure_log(conversation_id);
CREATE INDEX IF NOT EXISTS idx_agent_failure_log_type
    ON public.agent_failure_log(failure_type);
CREATE INDEX IF NOT EXISTS idx_agent_failure_log_created_at
    ON public.agent_failure_log(created_at DESC);
-- Fast "what still needs a human look" query: failures where either no retry
-- was possible, or the retry ran and still failed.
CREATE INDEX IF NOT EXISTS idx_agent_failure_log_needs_review
    ON public.agent_failure_log(created_at DESC)
    WHERE retry_succeeded IS DISTINCT FROM TRUE;

ALTER TABLE public.agent_failure_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_failure_log_select_own" ON public.agent_failure_log;
DROP POLICY IF EXISTS "agent_failure_log_insert_own" ON public.agent_failure_log;

-- Written exclusively by the backend via the service-role client (bypasses
-- RLS), same posture as agent_tasks/agent_actions. Own-row policies are kept
-- for consistency with every other table in this project, not because any
-- client currently reads this table.
CREATE POLICY "agent_failure_log_select_own" ON public.agent_failure_log
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "agent_failure_log_insert_own" ON public.agent_failure_log
    FOR INSERT WITH CHECK (auth.uid() = user_id);
