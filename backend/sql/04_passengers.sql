-- =============================================================================
-- FILE: sql/04_passengers.sql
-- PURPOSE: Passengers per booking (flights / trains)
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.passengers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id      UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Name fields
    title           TEXT CHECK (title IN ('Mr', 'Mrs', 'Ms', 'Dr', 'Prof')),
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,

    -- Identity
    date_of_birth   DATE,
    gender          TEXT CHECK (gender IN ('male', 'female')),
    nationality     TEXT DEFAULT 'Pakistani',
    cnic            TEXT,                  -- domestic travel
    passport_number TEXT,                  -- international travel

    -- Seat / class assignment (filled after confirmation)
    seat_number     TEXT,
    passenger_type  TEXT DEFAULT 'adult'
                    CHECK (passenger_type IN ('adult', 'child', 'infant')),

    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_passengers_booking_id ON public.passengers(booking_id);
CREATE INDEX IF NOT EXISTS idx_passengers_user_id    ON public.passengers(user_id);

ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "passengers_select_own" ON public.passengers;
DROP POLICY IF EXISTS "passengers_insert_own" ON public.passengers;
DROP POLICY IF EXISTS "passengers_update_own" ON public.passengers;
DROP POLICY IF EXISTS "passengers_delete_own" ON public.passengers;

CREATE POLICY "passengers_select_own" ON public.passengers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "passengers_insert_own" ON public.passengers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "passengers_update_own" ON public.passengers
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "passengers_delete_own" ON public.passengers
    FOR DELETE USING (auth.uid() = user_id);
