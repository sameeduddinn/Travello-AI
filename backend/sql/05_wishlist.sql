-- =============================================================================
-- FILE: sql/05_wishlist.sql
-- PURPOSE: Wishlist — save flights / trains / hotels for later
-- RUN IN: Supabase SQL Editor (safe to re-run — idempotent)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.wishlist (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 'flight' | 'train' | 'hotel'
    item_type   TEXT NOT NULL CHECK (item_type IN ('flight', 'train', 'hotel')),

    -- Full item snapshot (whatever the search result object looks like)
    item_data   JSONB NOT NULL,

    -- Prevent exact duplicates per user
    -- (user_id, item_type, hash of item_data could be used but JSONB diffs are fine for FYP)
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user_id   ON public.wishlist(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_item_type ON public.wishlist(item_type);

ALTER TABLE public.wishlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wishlist_select_own" ON public.wishlist;
DROP POLICY IF EXISTS "wishlist_insert_own" ON public.wishlist;
DROP POLICY IF EXISTS "wishlist_delete_own" ON public.wishlist;

CREATE POLICY "wishlist_select_own" ON public.wishlist
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "wishlist_insert_own" ON public.wishlist
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wishlist_delete_own" ON public.wishlist
    FOR DELETE USING (auth.uid() = user_id);
