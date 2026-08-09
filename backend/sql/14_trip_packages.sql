-- =============================================================================
-- FILE: sql/14_trip_packages.sql
-- PURPOSE: Link the component bookings of ONE Trip Planner package together.
--
--   A Trip Planner package (transport + hotel + hub car transfer) is one trip
--   the traveller buys once, but it stays several booking rows internally so
--   tickets, PNRs, My Bookings and the per-component services keep working
--   exactly as they always have. package_id is the only thing that ties them
--   together — it is what makes ONE payment, ONE confirmation and ONE
--   consolidated email possible without duplicating the booking system.
--
--   NULL is the default and means "ordinary standalone booking". Every
--   existing row and every standalone flight/train/hotel/car booking keeps
--   package_id = NULL and is therefore untouched by the package code paths
--   BY CONSTRUCTION, not by a runtime check that could regress.
--
-- RUN IN: Supabase SQL Editor (safe to re-run — all statements are idempotent)
-- =============================================================================

ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS package_id TEXT;   -- e.g. PKG-A1B2C3 | NULL = standalone

-- Every package read is "give me the components of this package", so the index
-- is on package_id alone. Partial: standalone rows are the overwhelming
-- majority and are never looked up this way, so they stay out of the index.
CREATE INDEX IF NOT EXISTS idx_bookings_package_id
    ON public.bookings (package_id)
    WHERE package_id IS NOT NULL;
