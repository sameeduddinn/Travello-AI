-- =============================================================================
-- FILE: sql/06_notifications.sql
-- PURPOSE: In-app notifications for the user
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    title       TEXT NOT NULL,
    body        TEXT NOT NULL,

    -- 'booking_confirmed' | 'payment_success' | 'booking_cancelled' | 'otp' | 'promo' | 'system'
    type        TEXT DEFAULT 'system',

    is_read     BOOLEAN DEFAULT FALSE,

    -- Optional extra payload (e.g., booking_id for deep-link navigation in Flutter)
    data        JSONB DEFAULT '{}',

    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id   ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read   ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created   ON public.notifications(created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;

CREATE POLICY "notifications_select_own" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Notifications are typically inserted by server (service role bypasses RLS),
-- but allowing user inserts is fine for FYP demo.
CREATE POLICY "notifications_insert_own" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_update_own" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);
