-- =============================================================================
-- FILE: sql/09_ai_agent.sql
-- PURPOSE: AI Agent tables — conversations, messages, saved itineraries,
--          autonomous agent task queue, action audit log, and user feedback.
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- =============================================================================
-- TABLE: ai_conversations
-- One row per chat session the user starts with the AI assistant.
-- A single user can have many conversations (history threads).
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title       TEXT,                                   -- auto-set from first user message
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,      -- FALSE = archived / deleted
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_id
    ON public.ai_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_active
    ON public.ai_conversations(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_updated_at
    ON public.ai_conversations(updated_at DESC);

ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_conversations_select_own" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_insert_own" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_update_own" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_delete_own" ON public.ai_conversations;

CREATE POLICY "ai_conversations_select_own" ON public.ai_conversations
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ai_conversations_insert_own" ON public.ai_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ai_conversations_update_own" ON public.ai_conversations
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "ai_conversations_delete_own" ON public.ai_conversations
    FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS set_ai_conversations_updated_at ON public.ai_conversations;
CREATE TRIGGER set_ai_conversations_updated_at
    BEFORE UPDATE ON public.ai_conversations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- TABLE: ai_messages
-- Individual chat messages inside a conversation.
-- Stores both user turns and assistant turns so history can be replayed.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ai_messages (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id     UUID        NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 'user' | 'assistant' | 'system'
    role                TEXT        NOT NULL CHECK (role IN ('user', 'assistant', 'system')),

    -- Main text content of the message
    content             TEXT        NOT NULL,

    -- Distinguishes plain chat from rich structured responses
    -- 'text'          → plain conversational reply
    -- 'itinerary'     → AI generated a day-by-day trip plan (see metadata)
    -- 'action_result' → agent completed a task and returned results
    -- 'suggestion'    → clickable quick-reply chips
    -- 'error'         → agent/API failure message
    message_type        TEXT        NOT NULL DEFAULT 'text'
                        CHECK (message_type IN ('text', 'itinerary', 'action_result', 'suggestion', 'error')),

    -- Structured payload: itinerary days, search results, action details, etc.
    metadata            JSONB,

    -- LLM usage tracking (populated when a real Claude/GPT call is made)
    model_used          TEXT,                           -- e.g. 'claude-sonnet-4-6'
    input_tokens        INT,
    output_tokens       INT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation_id
    ON public.ai_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_messages_user_id
    ON public.ai_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_messages_conv_created
    ON public.ai_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_type
    ON public.ai_messages(message_type) WHERE message_type != 'text';

ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_messages_select_own" ON public.ai_messages;
DROP POLICY IF EXISTS "ai_messages_insert_own" ON public.ai_messages;
DROP POLICY IF EXISTS "ai_messages_delete_own" ON public.ai_messages;

CREATE POLICY "ai_messages_select_own" ON public.ai_messages
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ai_messages_insert_own" ON public.ai_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ai_messages_delete_own" ON public.ai_messages
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- TABLE: ai_saved_itineraries
-- Persisted trip plans generated (or saved) via the AI assistant.
-- Replaces the hard-coded in-memory _savedTrips list in the Flutter app.
--
-- itinerary_data JSONB shape:
-- {
--   "days": [
--     { "day": 1, "title": "Arrival", "icon": "flight_takeoff",
--       "activities": ["Land at airport", "Check in", ...] },
--     ...
--   ]
-- }
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ai_saved_itineraries (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Optionally linked to the conversation that produced this plan
    conversation_id     UUID        REFERENCES public.ai_conversations(id) ON DELETE SET NULL,

    -- Destination metadata
    destination         TEXT        NOT NULL,
    province            TEXT,
    image_url           TEXT,

    -- Trip parameters
    travel_style        TEXT        CHECK (travel_style IN (
                                        'Adventure', 'Cultural', 'Relaxing',
                                        'Family', 'Nature', 'Mixed')),
    duration_days       INT         NOT NULL DEFAULT 3 CHECK (duration_days > 0),
    budget_range        TEXT        CHECK (budget_range IN ('Budget', 'Mid-range', 'Luxury')),

    -- Full day-by-day plan stored as JSON
    itinerary_data      JSONB       NOT NULL,

    -- Optional user metadata
    trip_date           DATE,                           -- planned start date
    notes               TEXT,                           -- user's personal notes
    is_booked           BOOLEAN     NOT NULL DEFAULT FALSE,  -- marked true after booking

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_itineraries_user_id
    ON public.ai_saved_itineraries(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_itineraries_destination
    ON public.ai_saved_itineraries(destination);
CREATE INDEX IF NOT EXISTS idx_ai_itineraries_user_created
    ON public.ai_saved_itineraries(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_itineraries_booked
    ON public.ai_saved_itineraries(user_id, is_booked);

ALTER TABLE public.ai_saved_itineraries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_itineraries_select_own" ON public.ai_saved_itineraries;
DROP POLICY IF EXISTS "ai_itineraries_insert_own" ON public.ai_saved_itineraries;
DROP POLICY IF EXISTS "ai_itineraries_update_own" ON public.ai_saved_itineraries;
DROP POLICY IF EXISTS "ai_itineraries_delete_own" ON public.ai_saved_itineraries;

CREATE POLICY "ai_itineraries_select_own" ON public.ai_saved_itineraries
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ai_itineraries_insert_own" ON public.ai_saved_itineraries
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ai_itineraries_update_own" ON public.ai_saved_itineraries
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "ai_itineraries_delete_own" ON public.ai_saved_itineraries
    FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS set_ai_itineraries_updated_at ON public.ai_saved_itineraries;
CREATE TRIGGER set_ai_itineraries_updated_at
    BEFORE UPDATE ON public.ai_saved_itineraries
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- TABLE: agent_tasks
-- Task queue for the autonomous AI agent.
-- When the agent needs to perform multi-step work (search + compare + book),
-- each autonomous job is a row here, executed asynchronously.
--
-- task_params JSONB examples:
--   plan_trip:      { "destination": "Hunza", "duration": 5, "budget": "Mid-range" }
--   search_flights: { "origin": "KHI", "dest": "ISB", "date": "2026-05-01", "passengers": 2 }
--   price_alert:    { "route": "KHI-ISB", "target_price": 8000, "currency": "PKR" }
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.agent_tasks (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id     UUID        REFERENCES public.ai_conversations(id) ON DELETE SET NULL,

    -- What kind of autonomous task this is
    task_type           TEXT        NOT NULL
                        CHECK (task_type IN (
                            'plan_trip',
                            'search_flights',
                            'search_hotels',
                            'search_trains',
                            'price_alert',
                            'book_flight',
                            'book_hotel',
                            'book_train',
                            'weather_check',
                            'summarise_options',
                            'custom'
                        )),

    task_description    TEXT        NOT NULL,           -- human-readable description
    task_params         JSONB,                          -- structured input parameters

    -- Lifecycle
    status              TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled')),

    -- Higher number = higher priority (1=lowest, 5=critical)
    priority            SMALLINT    NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),

    -- Output
    result              JSONB,                          -- structured task output
    error_message       TEXT,

    -- Retry logic
    retry_count         SMALLINT    NOT NULL DEFAULT 0,
    max_retries         SMALLINT    NOT NULL DEFAULT 3,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_user_id
    ON public.agent_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_status
    ON public.agent_tasks(status) WHERE status IN ('pending', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_agent_tasks_user_status
    ON public.agent_tasks(user_id, status);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_priority
    ON public.agent_tasks(priority DESC, created_at ASC)
    WHERE status = 'pending';

ALTER TABLE public.agent_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_tasks_select_own" ON public.agent_tasks;
DROP POLICY IF EXISTS "agent_tasks_insert_own" ON public.agent_tasks;
DROP POLICY IF EXISTS "agent_tasks_update_own" ON public.agent_tasks;
DROP POLICY IF EXISTS "agent_tasks_delete_own" ON public.agent_tasks;

CREATE POLICY "agent_tasks_select_own" ON public.agent_tasks
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "agent_tasks_insert_own" ON public.agent_tasks
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "agent_tasks_update_own" ON public.agent_tasks
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "agent_tasks_delete_own" ON public.agent_tasks
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- TABLE: agent_actions
-- Granular audit log of every tool/API call the agent made during a task.
-- One task → many actions (search, compare, decide, book, notify).
--
-- action_params / action_result hold the raw input/output of each tool call.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.agent_actions (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id         UUID        NOT NULL REFERENCES public.agent_tasks(id) ON DELETE CASCADE,
    user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Which tool/API the agent invoked
    action_type     TEXT        NOT NULL
                    CHECK (action_type IN (
                        'search_flights',
                        'search_hotels',
                        'search_trains',
                        'fetch_weather',
                        'call_llm',
                        'save_itinerary',
                        'create_booking',
                        'send_notification',
                        'price_comparison',
                        'custom'
                    )),

    action_params   JSONB,                              -- what was sent to the tool
    action_result   JSONB,                              -- what came back

    status          TEXT        NOT NULL DEFAULT 'success'
                    CHECK (status IN ('success', 'failed', 'skipped')),

    duration_ms     INT,                                -- wall-clock time of the action
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_actions_task_id
    ON public.agent_actions(task_id);
CREATE INDEX IF NOT EXISTS idx_agent_actions_user_id
    ON public.agent_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_actions_task_executed
    ON public.agent_actions(task_id, executed_at ASC);
CREATE INDEX IF NOT EXISTS idx_agent_actions_failed
    ON public.agent_actions(user_id, status) WHERE status = 'failed';

ALTER TABLE public.agent_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_actions_select_own" ON public.agent_actions;
DROP POLICY IF EXISTS "agent_actions_insert_own" ON public.agent_actions;

CREATE POLICY "agent_actions_select_own" ON public.agent_actions
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "agent_actions_insert_own" ON public.agent_actions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- TABLE: ai_feedback
-- Thumbs-up / thumbs-down rating on individual AI messages.
-- Used to train / fine-tune and improve response quality over time.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ai_feedback (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_id      UUID        NOT NULL REFERENCES public.ai_messages(id) ON DELETE CASCADE,

    -- 1 = thumbs up (helpful), -1 = thumbs down (not helpful)
    rating          SMALLINT    NOT NULL CHECK (rating IN (1, -1)),
    feedback_text   TEXT,                               -- optional written comment

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, message_id)                        -- one rating per message per user
);

CREATE INDEX IF NOT EXISTS idx_ai_feedback_message_id
    ON public.ai_feedback(message_id);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_user_id
    ON public.ai_feedback(user_id);

ALTER TABLE public.ai_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_feedback_select_own" ON public.ai_feedback;
DROP POLICY IF EXISTS "ai_feedback_insert_own" ON public.ai_feedback;
DROP POLICY IF EXISTS "ai_feedback_update_own" ON public.ai_feedback;
DROP POLICY IF EXISTS "ai_feedback_delete_own" ON public.ai_feedback;

CREATE POLICY "ai_feedback_select_own" ON public.ai_feedback
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ai_feedback_insert_own" ON public.ai_feedback
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ai_feedback_update_own" ON public.ai_feedback
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "ai_feedback_delete_own" ON public.ai_feedback
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- VIEW: ai_conversation_summary
-- Handy view for listing a user's conversations with last message preview.
-- =============================================================================
DROP VIEW IF EXISTS public.ai_conversation_summary;

CREATE VIEW public.ai_conversation_summary AS
SELECT
    c.id,
    c.user_id,
    c.title,
    c.is_active,
    c.created_at,
    c.updated_at,
    COUNT(m.id)                                         AS message_count,
    MAX(m.created_at)                                   AS last_message_at,
    (
        SELECT content
        FROM   public.ai_messages sub
        WHERE  sub.conversation_id = c.id
        ORDER  BY sub.created_at DESC
        LIMIT  1
    )                                                   AS last_message_preview
FROM public.ai_conversations c
LEFT JOIN public.ai_messages m ON m.conversation_id = c.id
GROUP BY c.id, c.user_id, c.title, c.is_active, c.created_at, c.updated_at;

-- =============================================================================
-- VIEW: agent_task_summary
-- Lists agent tasks with their action count and last action status.
-- =============================================================================
DROP VIEW IF EXISTS public.agent_task_summary;

CREATE VIEW public.agent_task_summary AS
SELECT
    t.id,
    t.user_id,
    t.task_type,
    t.task_description,
    t.status,
    t.priority,
    t.retry_count,
    t.created_at,
    t.started_at,
    t.completed_at,
    EXTRACT(EPOCH FROM (COALESCE(t.completed_at, NOW()) - t.started_at))::INT
                                                        AS duration_seconds,
    COUNT(a.id)                                         AS action_count,
    SUM(CASE WHEN a.status = 'failed' THEN 1 ELSE 0 END) AS failed_actions
FROM public.agent_tasks t
LEFT JOIN public.agent_actions a ON a.task_id = t.id
GROUP BY t.id, t.user_id, t.task_type, t.task_description,
         t.status, t.priority, t.retry_count,
         t.created_at, t.started_at, t.completed_at;

-- =============================================================================
-- FUNCTION: archive_old_conversations
-- Archives conversations with no messages in the last 30 days.
-- Can be called periodically via pg_cron or a scheduled Supabase function.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.archive_old_conversations()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    affected INT;
BEGIN
    UPDATE public.ai_conversations
    SET    is_active = FALSE,
           updated_at = NOW()
    WHERE  is_active = TRUE
      AND  id NOT IN (
               SELECT DISTINCT conversation_id
               FROM   public.ai_messages
               WHERE  created_at > NOW() - INTERVAL '30 days'
           );

    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
