-- ============================================================================
-- Phase 5 — delivery-partner backend.
--   • Extends profiles with driver metadata.
--   • Adds partner_invites table (admin-invite flow for drivers).
--   • Adds deliveries table (per-assignment lifecycle).
--   • Updates handle_new_user trigger to auto-consume invites on signup.
--   • Adds RLS policies for all of the above.
--
-- Run once in Supabase SQL Editor. Safe to re-run (idempotent).
-- ============================================================================


-- ============================================================================
-- 1. Extend profiles with driver-specific columns (all nullable).
-- ============================================================================
alter table public.profiles
  add column if not exists vehicle           text,
  add column if not exists vehicle_number    text,
  add column if not exists rating            numeric(3,2) default 5.00,
  add column if not exists total_deliveries  int not null default 0,
  add column if not exists is_online         boolean not null default false,
  add column if not exists avatar_hex        text;

-- Helper: is_delivery(uid) — used in RLS.
create or replace function public.is_delivery(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'delivery'
  );
$$;


-- ============================================================================
-- 2. partner_invites — admin creates a row, driver signs up with that email,
--    the handle_new_user trigger consumes the invite and promotes them.
-- ============================================================================
create table if not exists public.partner_invites (
  id              uuid primary key default gen_random_uuid(),
  email           text not null unique,
  name            text not null,
  phone           text not null,
  vehicle         text not null,
  vehicle_number  text not null,
  created_by      uuid references auth.users(id) on delete set null,
  consumed_at     timestamptz,
  consumed_by     uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now()
);

create index if not exists idx_partner_invites_email
  on public.partner_invites(lower(email));

alter table public.partner_invites enable row level security;

drop policy if exists "partner_invites_admin_rw" on public.partner_invites;
create policy "partner_invites_admin_rw"
  on public.partner_invites for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- ============================================================================
-- 3. Update handle_new_user trigger to consume partner_invites on signup.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.partner_invites%rowtype;
begin
  select *
    into v_invite
    from public.partner_invites
   where lower(email) = lower(new.email)
     and consumed_at is null
   limit 1;

  if v_invite.id is not null then
    insert into public.profiles
      (id, phone, email, name, role, vehicle, vehicle_number)
    values
      (new.id, coalesce(new.phone, v_invite.phone), new.email,
       v_invite.name, 'delivery', v_invite.vehicle, v_invite.vehicle_number)
    on conflict (id) do update
      set role           = 'delivery',
          name           = excluded.name,
          phone          = excluded.phone,
          vehicle        = excluded.vehicle,
          vehicle_number = excluded.vehicle_number;

    update public.partner_invites
       set consumed_at = now(),
           consumed_by = new.id
     where id = v_invite.id;
  else
    insert into public.profiles (id, phone, email)
    values (new.id, new.phone, new.email)
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;


-- ============================================================================
-- 4. deliveries — per-assignment lifecycle.
-- ============================================================================
do $$ begin
  create type delivery_status as enum
    ('offered','accepted','picked_up','delivered','cancelled','declined');
exception when duplicate_object then null; end $$;

create table if not exists public.deliveries (
  id                uuid primary key default gen_random_uuid(),
  order_id          uuid not null references public.orders(id) on delete cascade,
  driver_id         uuid references auth.users(id) on delete set null,
  status            delivery_status not null default 'offered',
  pickup_address    text not null,
  drop_address      text not null,
  distance_km       numeric(5,2) not null default 0,
  earning_amount    numeric(8,2) not null default 0,
  item_count        int not null default 0,
  restaurant_name   text,
  customer_name     text,
  customer_phone    text,
  event_label       text,
  guest_count       int,
  delivery_otp      text not null,
  eta_minutes       int,
  offered_at        timestamptz not null default now(),
  accepted_at       timestamptz,
  picked_up_at      timestamptz,
  delivered_at      timestamptz,
  cancelled_at      timestamptz,
  created_by        uuid references auth.users(id) on delete set null
);
create index if not exists idx_deliveries_driver   on public.deliveries(driver_id);
create index if not exists idx_deliveries_status   on public.deliveries(status);
create index if not exists idx_deliveries_order    on public.deliveries(order_id);

alter table public.deliveries enable row level security;

-- Admins: full R/W.
drop policy if exists "deliveries_admin_all" on public.deliveries;
create policy "deliveries_admin_all"
  on public.deliveries for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- Drivers: can read all OFFERED assignments + any assigned to them; can update
-- their own assignment (accept/pickup/deliver).
drop policy if exists "deliveries_driver_read" on public.deliveries;
create policy "deliveries_driver_read"
  on public.deliveries for select
  using (
    public.is_delivery(auth.uid()) and
    (status = 'offered' or driver_id = auth.uid())
  );

drop policy if exists "deliveries_driver_update" on public.deliveries;
create policy "deliveries_driver_update"
  on public.deliveries for update
  using (
    public.is_delivery(auth.uid()) and
    (driver_id = auth.uid() or (status = 'offered' and driver_id is null))
  )
  with check (
    public.is_delivery(auth.uid()) and
    (driver_id = auth.uid() or driver_id is null)
  );

-- Drivers: toggle their own online flag on profiles.
drop policy if exists "profiles_driver_self_update" on public.profiles;
create policy "profiles_driver_self_update"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());


-- ============================================================================
-- 5. Verify
-- ============================================================================
-- select column_name, data_type
--   from information_schema.columns
--  where table_schema = 'public' and table_name = 'profiles' order by ordinal_position;
-- select * from public.partner_invites;
-- select * from public.deliveries;
