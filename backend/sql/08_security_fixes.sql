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
-- 3. Supabase Storage — avatars bucket policies
--    Run AFTER creating the 'avatars' bucket in Supabase Dashboard → Storage
--    Bucket must be set to PUBLIC
-- ---------------------------------------------------------------------------

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow public to view all avatars (needed for public URL to work)
CREATE POLICY "Avatars are publicly viewable"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Allow users to replace/update their own avatar (upsert: true)
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ---------------------------------------------------------------------------
-- 3. saved_searches table
-- ---------------------------------------------------------------------------
-- If table already exists from sql/07 (which used column 'search_params'),
-- add the 'query' column that the API router expects.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'saved_searches'
          AND column_name  = 'search_params'
    ) THEN
        ALTER TABLE public.saved_searches ADD COLUMN IF NOT EXISTS query jsonb DEFAULT '{}';
    END IF;
END $$;

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
-- If table already exists from sql/07 (which had booking_id as UUID FK),
-- the router uses booking_id as TEXT (human-readable TRV-FL-... code).
-- Drop and recreate with the correct schema.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'reviews'
          AND column_name  = 'booking_id'
          AND data_type    = 'uuid'
    ) THEN
        DROP TABLE IF EXISTS public.reviews CASCADE;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.reviews (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    booking_id   text NOT NULL UNIQUE,  -- human-readable booking ID (TRV-FL-...), one review per booking
    booking_uuid uuid,                  -- UUID of the booking row (for joins)
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
