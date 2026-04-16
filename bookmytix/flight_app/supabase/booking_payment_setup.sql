-- Supabase setup for booking + payment OTP + transactional email (demo-safe)
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  booking_id text not null unique,
  booking_type text not null check (booking_type in ('flight', 'train', 'hotel')),
  pnr text,
  transaction_id text,
  contact_email text not null,
  contact_phone text,
  total_amount numeric(12,2) not null default 0,
  currency text not null default 'PKR',
  status text not null default 'confirmed',
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_bookings_user_id on public.bookings(user_id);
create index if not exists idx_bookings_created_at on public.bookings(created_at desc);
create index if not exists idx_bookings_booking_type on public.bookings(booking_type);
create index if not exists idx_bookings_status on public.bookings(status);

create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  booking_id text,
  payment_method text not null,
  amount numeric(12,2) not null default 0,
  currency text not null default 'PKR',
  status text not null check (status in ('initiated', 'otp_sent', 'otp_verified', 'success', 'failed', 'simulated_success', 'simulated_failed')),
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_payment_attempts_user_id on public.payment_attempts(user_id);
create index if not exists idx_payment_attempts_booking_id on public.payment_attempts(booking_id);
create index if not exists idx_payment_attempts_created_at on public.payment_attempts(created_at desc);

-- OTP requests table is for edge functions (service role).
create table if not exists public.payment_otps (
  id uuid primary key default gen_random_uuid(),
  request_id text not null unique,
  user_id uuid references auth.users(id) on delete set null,
  email text,
  phone text,
  provider text not null,
  otp_hash text not null,
  attempts int not null default 0,
  verified boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

create index if not exists idx_payment_otps_request_id on public.payment_otps(request_id);
create index if not exists idx_payment_otps_expires_at on public.payment_otps(expires_at);

alter table public.bookings enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.payment_otps enable row level security;

-- bookings policies
drop policy if exists "bookings_select_own" on public.bookings;
create policy "bookings_select_own"
on public.bookings
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "bookings_insert_own" on public.bookings;
create policy "bookings_insert_own"
on public.bookings
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "bookings_update_own" on public.bookings;
create policy "bookings_update_own"
on public.bookings
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- payment_attempts policies
drop policy if exists "payment_attempts_select_own" on public.payment_attempts;
create policy "payment_attempts_select_own"
on public.payment_attempts
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "payment_attempts_insert_own" on public.payment_attempts;
create policy "payment_attempts_insert_own"
on public.payment_attempts
for insert
to authenticated
with check (user_id = auth.uid());

-- No direct client access to payment_otps; edge functions use service role key.

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_bookings_touch_updated_at on public.bookings;
create trigger trg_bookings_touch_updated_at
before update on public.bookings
for each row execute function public.touch_updated_at();
