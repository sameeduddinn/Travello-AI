-- =============================================================================
-- FILE: sql/01_profiles.sql
-- PURPOSE: User profiles and preferences tables with RLS policies
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

-- Enable UUID extension (already enabled in Supabase by default)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- TABLE: profiles
-- Linked 1:1 to auth.users via id (UUID)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT,
    phone           TEXT,
    date_of_birth   DATE,
    gender          TEXT CHECK (gender IN ('male', 'female', 'other')),
    nationality     TEXT DEFAULT 'Pakistani',
    cnic            TEXT,                          -- Pakistani CNIC: 13 digits
    passport_number TEXT,
    avatar_url      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"  ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- =============================================================================
-- TABLE: user_preferences
-- Stores per-user app preferences
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.user_preferences (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    origin_city TEXT DEFAULT 'Karachi',
    currency    TEXT DEFAULT 'PKR',
    theme       TEXT DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'system')),
    language    TEXT DEFAULT 'en',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "preferences_select_own"  ON public.user_preferences;
DROP POLICY IF EXISTS "preferences_insert_own"  ON public.user_preferences;
DROP POLICY IF EXISTS "preferences_update_own"  ON public.user_preferences;

CREATE POLICY "preferences_select_own" ON public.user_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "preferences_insert_own" ON public.user_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "preferences_update_own" ON public.user_preferences
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- FUNCTION + TRIGGER: auto-create profile row on new user signup
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.user_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- FUNCTION: auto-update updated_at on row change
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_preferences_updated_at ON public.user_preferences;
CREATE TRIGGER set_preferences_updated_at
    BEFORE UPDATE ON public.user_preferences
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
