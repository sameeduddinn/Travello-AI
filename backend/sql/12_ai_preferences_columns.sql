-- =============================================================================
-- FILE: sql/12_ai_preferences_columns.sql
-- PURPOSE: Add AI agent preference columns to user_preferences table.
--
--   The original 01_profiles.sql only created: origin_city, currency, theme,
--   language. The AI memory agent needs 5 additional columns for preference
--   learning. past_destinations is JSONB (stores a list of city strings).
--
-- RUN IN: Supabase SQL Editor (safe to re-run — all statements are idempotent)
-- =============================================================================

ALTER TABLE public.user_preferences
    ADD COLUMN IF NOT EXISTS preferred_class    TEXT,           -- Economy | Business | First
    ADD COLUMN IF NOT EXISTS travel_style       TEXT,           -- budget | standard | luxury
    ADD COLUMN IF NOT EXISTS companion_type     TEXT,           -- solo | couple | family | group
    ADD COLUMN IF NOT EXISTS budget_style       TEXT,           -- budget | standard | luxury
    ADD COLUMN IF NOT EXISTS past_destinations  JSONB DEFAULT '[]'::JSONB;  -- ["Lahore","Hunza"]

-- Backfill: ensure existing rows have an empty array (not NULL) for past_destinations
UPDATE public.user_preferences
SET    past_destinations = '[]'::JSONB
WHERE  past_destinations IS NULL;
