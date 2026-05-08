-- =============================================================================
-- FILE: sql/10_support_messages.sql
-- PURPOSE: Support messages table — stores user support requests and admin replies.
-- Run in Supabase Dashboard → SQL Editor after applying 01–09 scripts.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.support_messages (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email  text        NOT NULL DEFAULT '',
    topic       text        NOT NULL,
    subject     text        NOT NULL,
    description text        NOT NULL,
    status      text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'replied', 'closed')),
    admin_reply text,
    replied_at  timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- Users can view only their own messages
CREATE POLICY "Users can view own support messages"
    ON public.support_messages FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own messages
CREATE POLICY "Users can insert own support messages"
    ON public.support_messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- service_role bypasses RLS — used by admin reply endpoint

CREATE INDEX IF NOT EXISTS idx_support_messages_user_id
    ON public.support_messages(user_id, created_at DESC);

-- Auto-update updated_at on every change
CREATE OR REPLACE FUNCTION update_support_messages_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_support_messages_updated_at ON public.support_messages;
CREATE TRIGGER trg_support_messages_updated_at
    BEFORE UPDATE ON public.support_messages
    FOR EACH ROW EXECUTE FUNCTION update_support_messages_updated_at();
