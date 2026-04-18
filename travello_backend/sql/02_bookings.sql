-- =============================================================================
-- FILE: sql/02_bookings.sql
-- PURPOSE: Bookings table — flights, trains, hotels all unified here
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- =============================================================================
-- TABLE: bookings
-- Central table for all booking types
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.bookings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Human-readable identifiers
    booking_id      TEXT UNIQUE NOT NULL,          -- e.g. TRV-FL-20240417-ABCD
    booking_type    TEXT NOT NULL CHECK (booking_type IN ('flight', 'train', 'hotel')),
    pnr             TEXT,                          -- Passenger Name Record / confirmation number

    -- Payment linkage
    transaction_id  TEXT,                          -- set after payment success

    -- Contact info at time of booking
    contact_email   TEXT NOT NULL,
    contact_phone   TEXT,

    -- Financials
    total_amount    NUMERIC(12, 2) NOT NULL,
    currency        TEXT DEFAULT 'PKR',

    -- Status lifecycle: pending → paid → confirmed → cancelled | refunded
    status          TEXT DEFAULT 'pending'
                    CHECK (status IN ('pending', 'paid', 'confirmed', 'cancelled', 'refunded')),

    -- Full API response / computed payload stored as-is for ticket rendering
    raw_payload     JSONB,

    -- Booking-type-specific denormalised fields for quick list display
    origin          TEXT,                          -- flights/trains: origin city/station
    destination     TEXT,                          -- flights/trains: destination
    departure_at    TIMESTAMPTZ,                   -- flights/trains: departure datetime
    arrival_at      TIMESTAMPTZ,                   -- flights/trains: arrival datetime
    hotel_name      TEXT,                          -- hotels only
    check_in        DATE,                          -- hotels only
    check_out       DATE,                          -- hotels only

    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_bookings_user_id     ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status      ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_type        ON public.bookings(booking_type);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_id  ON public.bookings(booking_id);
CREATE INDEX IF NOT EXISTS idx_bookings_created_at  ON public.bookings(created_at DESC);

-- RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_own" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_own" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_own" ON public.bookings;

CREATE POLICY "bookings_select_own" ON public.bookings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "bookings_insert_own" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow user to cancel their own booking (status update only — enforced in API layer)
CREATE POLICY "bookings_update_own" ON public.bookings
    FOR UPDATE USING (auth.uid() = user_id);

-- updated_at trigger
DROP TRIGGER IF EXISTS set_bookings_updated_at ON public.bookings;
CREATE TRIGGER set_bookings_updated_at
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- FUNCTION: generate_booking_id
-- Generates a human-readable booking reference like TRV-FL-20240417-A1B2
-- =============================================================================
CREATE OR REPLACE FUNCTION public.generate_booking_id(p_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix TEXT;
    v_date   TEXT;
    v_rand   TEXT;
BEGIN
    v_prefix := CASE p_type
        WHEN 'flight' THEN 'TRV-FL'
        WHEN 'train'  THEN 'TRV-TR'
        WHEN 'hotel'  THEN 'TRV-HT'
        ELSE 'TRV-XX'
    END;

    v_date := TO_CHAR(NOW(), 'YYYYMMDD');
    v_rand := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    RETURN v_prefix || '-' || v_date || '-' || v_rand;
END;
$$;
