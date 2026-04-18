-- =============================================================================
-- FILE: sql/08_security_fixes.sql
-- PURPOSE: Security hardening, performance indexes, and new feature tables.
-- Run in Supabase Dashboard → SQL Editor after applying 01–07 scripts.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Revoke direct access to booking_summary view
--    Only service_role (backend) can access it — prevents data leaks via anon
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.booking_summary FROM anon, authenticated;
GRANT SELECT ON public.booking_summary TO service_role;

-- ---------------------------------------------------------------------------
-- 2. Performance indexes
-- ---------------------------------------------------------------------------

-- OTP rate limiting query: user + created_at
CREATE INDEX IF NOT EXISTS idx_payment_otps_user_created
    ON public.payment_otps(user_id, created_at DESC);

-- Duplicate booking prevention query: user + type + status + time
CREATE INDEX IF NOT EXISTS idx_bookings_user_type_status
    ON public.bookings(user_id, booking_type, status, created_at DESC);

-- Passenger lookup by booking_id (used by passenger-check on payment initiate)
CREATE INDEX IF NOT EXISTS idx_passengers_booking_id
    ON public.passengers(booking_id);

-- ---------------------------------------------------------------------------
-- 3. saved_searches table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.saved_searches (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    search_type text NOT NULL CHECK (search_type IN ('flight', 'train', 'hotel')),
    query       jsonb NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own saved searches"
    ON public.saved_searches
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id
    ON public.saved_searches(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 4. reviews table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    booking_id   text NOT NULL UNIQUE,  -- human-readable booking ID, one review per booking
    booking_uuid uuid,
    rating       smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own reviews"
    ON public.reviews
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_reviews_user_id
    ON public.reviews(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reviews_booking_id
    ON public.reviews(booking_id);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_updated_at ON public.reviews;
CREATE TRIGGER trg_reviews_updated_at
    BEFORE UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION update_reviews_updated_at();
