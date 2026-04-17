-- ============================================================================
--  Dawat — Addresses migration (v2)
--  Adds saved-addresses feature + atomic upsert RPC.
--  Run in the Supabase SQL editor. Idempotent — safe to re-run.
-- ============================================================================

create table if not exists public.user_addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null check (label in ('Home','Work','Other')),
  full_address text not null check (char_length(full_address) between 3 and 500),
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_addresses_user on public.user_addresses(user_id);

-- Only one default address per user.
create unique index if not exists ux_addresses_one_default
  on public.user_addresses(user_id) where is_default;

-- RLS
alter table public.user_addresses enable row level security;

drop policy if exists "addresses_owner_rw"   on public.user_addresses;
drop policy if exists "addresses_admin_read" on public.user_addresses;

create policy "addresses_owner_rw"
  on public.user_addresses for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "addresses_admin_read"
  on public.user_addresses for select
  using (public.is_admin(auth.uid()));

-- ----------------------------------------------------------------------------
-- Atomic upsert: ensures only one default address per user, in a single
-- transaction. Clears any previous default, then inserts/updates the target.
-- Accepts a NULL id to mean "create new".
-- Returns the final row.
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- Atomic "set this address as default" — flips the default in a single txn.
-- Safer than doing two client-side updates against the partial unique index.
-- ----------------------------------------------------------------------------
create or replace function public.set_default_address(p_id uuid)
returns public.user_addresses
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_addresses;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Ensure target belongs to caller.
  if not exists (
    select 1 from public.user_addresses
     where id = p_id and user_id = v_uid
  ) then
    raise exception 'address not found or not yours';
  end if;

  update public.user_addresses
     set is_default = false, updated_at = now()
   where user_id = v_uid and is_default and id <> p_id;

  update public.user_addresses
     set is_default = true, updated_at = now()
   where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.upsert_address(
  p_id          uuid,
  p_label       text,
  p_address     text,
  p_is_default  boolean
) returns public.user_addresses
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_addresses;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_is_default then
    -- Clear any other defaults atomically.
    update public.user_addresses
       set is_default = false, updated_at = now()
     where user_id = v_uid and is_default
       and (p_id is null or id <> p_id);
  end if;

  if p_id is null then
    insert into public.user_addresses (user_id, label, full_address, is_default)
    values (v_uid, p_label, p_address, coalesce(p_is_default, false))
    returning * into v_row;
  else
    update public.user_addresses
       set label = p_label,
           full_address = p_address,
           is_default = coalesce(p_is_default, is_default),
           updated_at = now()
     where id = p_id and user_id = v_uid
    returning * into v_row;
    if v_row.id is null then
      raise exception 'address not found or not yours';
    end if;
  end if;

  return v_row;
end;
$$;
