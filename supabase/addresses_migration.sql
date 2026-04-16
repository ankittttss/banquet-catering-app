-- ============================================================================
--  Dawat — Addresses migration
--  Adds saved-addresses feature: users can save Home / Work / Other addresses
--  and reuse them when planning events. Run in the Supabase SQL editor.
-- ============================================================================

create table if not exists public.user_addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null check (label in ('Home','Work','Other')),
  full_address text not null,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_addresses_user on public.user_addresses(user_id);

-- Only one default address per user.
create unique index if not exists ux_addresses_one_default
  on public.user_addresses(user_id) where is_default;

-- RLS
alter table public.user_addresses enable row level security;

drop policy if exists "addresses_owner_rw"       on public.user_addresses;
drop policy if exists "addresses_admin_read"     on public.user_addresses;

create policy "addresses_owner_rw"
  on public.user_addresses for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "addresses_admin_read"
  on public.user_addresses for select
  using (public.is_admin(auth.uid()));
