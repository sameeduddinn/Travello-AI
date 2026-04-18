-- =============================================================================
-- FILE: sql/03_payments.sql
-- PURPOSE: Payment attempts and OTP verification tables
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- =============================================================================
-- TABLE: payment_attempts
-- Each row = one attempt to pay for a booking
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.payment_attempts (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    booking_id         UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,

    payment_method     TEXT NOT NULL CHECK (payment_method IN ('jazzcash', 'easypaisa', 'card', 'bank_transfer')),

    amount             NUMERIC(12, 2) NOT NULL,
    currency           TEXT DEFAULT 'PKR',

    -- pending → otp_sent → completed | failed | expired
    status             TEXT DEFAULT 'pending'
                       CHECK (status IN ('pending', 'otp_sent', 'completed', 'failed', 'expired')),

    -- Reference returned by the simulated gateway
    provider_reference TEXT,

    -- Any extra data: phone used, card last 4, etc.
    metadata           JSONB DEFAULT '{}',

    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_user_id    ON public.payment_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_booking_id ON public.payment_attempts(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_status     ON public.payment_attempts(status);

ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payment_attempts_select_own" ON public.payment_attempts;
DROP POLICY IF EXISTS "payment_attempts_insert_own" ON public.payment_attempts;
DROP POLICY IF EXISTS "payment_attempts_update_own" ON public.payment_attempts;

CREATE POLICY "payment_attempts_select_own" ON public.payment_attempts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "payment_attempts_insert_own" ON public.payment_attempts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "payment_attempts_update_own" ON public.payment_attempts
    FOR UPDATE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS set_payment_attempts_updated_at ON public.payment_attempts;
CREATE TRIGGER set_payment_attempts_updated_at
    BEFORE UPDATE ON public.payment_attempts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- TABLE: payment_otps
-- Stores hashed OTP codes for JazzCash / EasyPaisa simulation
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.payment_otps (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Links back to the payment_attempt this OTP belongs to
    request_id  UUID NOT NULL REFERENCES public.payment_attempts(id) ON DELETE CASCADE,

    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT NOT NULL,                      -- OTP was "sent" to this email
    phone       TEXT,                               -- phone on file (display only)
    provider    TEXT NOT NULL CHECK (provider IN ('jazzcash', 'easypaisa')),

    -- bcrypt hash of the 6-digit OTP
    otp_hash    TEXT NOT NULL,

    -- Abuse protection
    attempts    INT DEFAULT 0,

    -- Lifecycle
    verified    BOOLEAN DEFAULT FALSE,
    expires_at  TIMESTAMPTZ NOT NULL,               -- now() + 10 minutes
    verified_at TIMESTAMPTZ,

    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_otps_request_id ON public.payment_otps(request_id);
CREATE INDEX IF NOT EXISTS idx_payment_otps_user_id    ON public.payment_otps(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_otps_verified   ON public.payment_otps(verified);

ALTER TABLE public.payment_otps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payment_otps_select_own" ON public.payment_otps;
DROP POLICY IF EXISTS "payment_otps_insert_own" ON public.payment_otps;
DROP POLICY IF EXISTS "payment_otps_update_own" ON public.payment_otps;

-- Users can only see their own OTPs
CREATE POLICY "payment_otps_select_own" ON public.payment_otps
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "payment_otps_insert_own" ON public.payment_otps
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "payment_otps_update_own" ON public.payment_otps
    FOR UPDATE USING (auth.uid() = user_id);
