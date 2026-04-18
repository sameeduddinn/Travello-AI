-- =============================================================================
-- FILE: sql/07_indexes_and_triggers.sql
-- PURPOSE: Saved searches, reviews, extra composite indexes, and maintenance
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- =============================================================================
-- NEW TABLE: saved_searches
-- Let users save frequently used search queries
-- =============================================================================
-- =============================================================================
-- FILE: sql/07_indexes_and_triggers.sql
-- PURPOSE: Saved searches, reviews, extra composite indexes, and maintenance
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- =============================================================================
-- NEW TABLE: saved_searches
-- Let users save frequently used search queries
-- =============================================================================
-- Add missing columns to bookings table
ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS origin       TEXT,
    ADD COLUMN IF NOT EXISTS destination  TEXT,
    ADD COLUMN IF NOT EXISTS departure_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS arrival_at   TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS hotel_name   TEXT,
    ADD COLUMN IF NOT EXISTS check_in     DATE,
    ADD COLUMN IF NOT EXISTS check_out    DATE;
    
CREATE TABLE IF NOT EXISTS public.saved_searches (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    search_type     TEXT NOT NULL CHECK (search_type IN ('flight', 'train', 'hotel')),
    search_params   JSONB NOT NULL,
    label           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id
    ON public.saved_searches(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_searches_search_type
    ON public.saved_searches(search_type);
CREATE INDEX IF NOT EXISTS idx_saved_searches_created_at
    ON public.saved_searches(created_at DESC);

ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "saved_searches_select_own" ON public.saved_searches;
DROP POLICY IF EXISTS "saved_searches_insert_own" ON public.saved_searches;
DROP POLICY IF EXISTS "saved_searches_delete_own" ON public.saved_searches;

CREATE POLICY "saved_searches_select_own" ON public.saved_searches
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "saved_searches_insert_own" ON public.saved_searches
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "saved_searches_delete_own" ON public.saved_searches
    FOR DELETE USING (auth.uid() = user_id);

-- ================================================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    booking_id  UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, booking_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_user_id
    ON public.reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id
    ON public.reviews(booking_id);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews_select_own" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_own" ON public.reviews;
DROP POLICY IF EXISTS "reviews_update_own" ON public.reviews;
DROP POLICY IF EXISTS "reviews_delete_own" ON public.reviews;

CREATE POLICY "reviews_select_own" ON public.reviews
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "reviews_insert_own" ON public.reviews
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reviews_update_own" ON public.reviews
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "reviews_delete_own" ON public.reviews
    FOR DELETE USING (auth.uid() = user_id);

-- ================================================================
-- COMPOSITE INDEXES
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_bookings_user_created
    ON public.bookings(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_user_status
    ON public.bookings(user_id, status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_passengers_booking_user
    ON public.passengers(booking_id, user_id);
CREATE INDEX IF NOT EXISTS idx_payment_otps_request_verified
    ON public.payment_otps(request_id, verified);

-- ================================================================
-- VIEW: booking_summary
-- ================================================================
DROP VIEW IF EXISTS public.booking_summary;

CREATE VIEW public.booking_summary AS
SELECT
    b.id,
    b.user_id,
    b.booking_id,
    b.booking_type,
    b.pnr,
    b.status,
    b.total_amount,
    b.currency,
    b.contact_email,
    b.contact_phone,
    b.origin,
    b.destination,
    b.departure_at,
    b.arrival_at,
    b.hotel_name,
    b.check_in,
    b.check_out,
    b.created_at,
    b.updated_at,
    COUNT(p.id)    AS passenger_count,
    pa.status      AS payment_status,
    pa.payment_method
FROM public.bookings b
LEFT JOIN public.passengers p
       ON p.booking_id = b.id
LEFT JOIN public.payment_attempts pa
       ON pa.booking_id = b.id::text
      AND pa.status = 'completed'
GROUP BY
    b.id,
    b.user_id,
    b.booking_id,
    b.booking_type,
    b.pnr,
    b.status,
    b.total_amount,
    b.currency,
    b.contact_email,
    b.contact_phone,
    b.origin,
    b.destination,
    b.departure_at,
    b.arrival_at,
    b.hotel_name,
    b.check_in,
    b.check_out,
    b.created_at,
    b.updated_at,
    pa.status,
    pa.payment_method;

-- ================================================================
-- FUNCTION: get_unread_count
-- ================================================================
CREATE OR REPLACE FUNCTION public.get_unread_count(p_user_id UUID)
RETURNS INT
LANGUAGE sql STABLE
AS $$
    SELECT COUNT(*)::INT
    FROM public.notifications
    WHERE user_id = p_user_id
      AND is_read = FALSE;
$$;