-- ============================================================================
-- Phase 37 — Catalog hardening (RLS visibility, price band, soft-delete)
-- ----------------------------------------------------------------------------
-- 1. RLS: stop the anon/customer key from reading draft/suspended/archived
--    restaurants and the menu items of hidden restaurants. Operators (any
--    non-customer role) and admins keep full read; a customer additionally
--    keeps read access to restaurants/items that appear in their OWN orders
--    (so order history still resolves names).
-- 2. Trigger: recompute the per-guest budget band when the plate price is
--    edited (previously it was only ever filled when NULL).
-- 3. menu_items.deleted_at: soft-delete, because order_items.menu_item_id is
--    NOT NULL + ON DELETE RESTRICT and carries no name snapshot — hard delete
--    of an ordered dish fails and would erase order-history names.
-- 4. search_menu_items: also hide soft-deleted rows.
--
-- Idempotent. No data is destroyed.
-- ============================================================================

-- ── 1) RLS ──────────────────────────────────────────────────────────────────

-- SECURITY DEFINER helper: is the caller a staff/operator (any non-customer
-- role)? Definer avoids RLS recursion on profiles.
create or replace function public.is_staff_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role <> 'customer'
  );
$$;

-- Restaurants: replace the open "read all" with a visibility-gated policy.
drop policy if exists restaurants_read_all on public.restaurants;
drop policy if exists restaurants_public_read on public.restaurants;
create policy restaurants_public_read on public.restaurants
  for select
  using (
    status = 'published'
    or public.is_staff_user()
    or exists (
      select 1 from public.orders o
      where o.restaurant_id = restaurants.id and o.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.order_vendor_lots l
      join public.orders o on o.id = l.order_id
      where l.restaurant_id = restaurants.id and o.user_id = auth.uid()
    )
  );

-- Menu items: visible when the caller is staff, when the parent restaurant is
-- published, or when the item appears in one of the caller's own orders.
drop policy if exists menu_items_read_all on public.menu_items;
drop policy if exists menu_items_public_read on public.menu_items;
create policy menu_items_public_read on public.menu_items
  for select
  using (
    public.is_staff_user()
    or exists (
      select 1 from public.restaurants r
      where r.id = menu_items.restaurant_id and r.status = 'published'
    )
    or exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.menu_item_id = menu_items.id and o.user_id = auth.uid()
    )
  );

-- ── 2) Soft-delete column (before the trigger re-reads it) ──────────────────

alter table public.menu_items
  add column if not exists deleted_at timestamptz;

-- ── 3) Trigger: recompute the per-guest band on plate-price change ──────────

create or replace function public.restaurants_before_write()
returns trigger
language plpgsql
as $$
declare
  entering_published boolean :=
    new.status = 'published'
    and (tg_op = 'INSERT' or old.status is distinct from 'published');
begin
  -- a) Publish gate — refuse to publish an incomplete restaurant.
  if entering_published then
    if coalesce(trim(new.name), '') = '' then
      raise exception 'Cannot publish: restaurant name is required.';
    end if;
    if new.price_per_plate is null or new.price_per_plate <= 0 then
      raise exception 'Cannot publish "%": price per plate is required.', new.name;
    end if;
    if new.min_guests is null or new.min_guests <= 0 then
      raise exception 'Cannot publish "%": minimum guests is required.', new.name;
    end if;
    if coalesce(trim(new.address), '') = ''
       or new.latitude is null
       or new.longitude is null then
      raise exception 'Cannot publish "%": address and map location are required.', new.name;
    end if;
    if new.logo_url is null and new.cover_image_url is null then
      raise exception 'Cannot publish "%": a logo or cover image is required.', new.name;
    end if;
    if not exists (
      select 1 from public.menu_items mi
      where mi.restaurant_id = new.id
        and mi.is_available
        and mi.deleted_at is null
    ) then
      raise exception 'Cannot publish "%": add at least one available menu item first.', new.name;
    end if;
  end if;

  -- b) is_active mirrors status.
  new.is_active := (new.status = 'published');

  -- c) Per-guest budget band. Derive it from the plate price when missing
  --    (new rows), AND recompute it when the plate price is edited without the
  --    caller explicitly changing the band in the same write (so manual band
  --    overrides are preserved but stale bands don't linger — phase37).
  if new.price_per_plate is not null then
    if new.per_guest_price_min is null then
      new.per_guest_price_min :=
        greatest((new.price_per_plate * 0.80)::numeric(10, 2), 120);
    end if;
    if new.per_guest_price_max is null then
      new.per_guest_price_max :=
        greatest((new.price_per_plate * 1.30)::numeric(10, 2), 250);
    end if;
    if tg_op = 'UPDATE'
       and new.price_per_plate is distinct from old.price_per_plate
       and new.per_guest_price_min is not distinct from old.per_guest_price_min
       and new.per_guest_price_max is not distinct from old.per_guest_price_max
    then
      new.per_guest_price_min :=
        greatest((new.price_per_plate * 0.80)::numeric(10, 2), 120);
      new.per_guest_price_max :=
        greatest((new.price_per_plate * 1.30)::numeric(10, 2), 250);
    end if;
  end if;

  -- d) Lifecycle timestamps.
  if entering_published then
    new.published_at := now();
  end if;
  if new.status = 'archived'
     and (tg_op = 'INSERT' or old.status is distinct from 'archived') then
    new.archived_at := now();
  end if;
  if tg_op = 'UPDATE'
     and old.status = 'archived'
     and new.status <> 'archived' then
    new.archived_at := null;
  end if;

  if tg_op = 'UPDATE' then
    new.updated_at := now();
  end if;

  return new;
end;
$$;

-- ── 4) search_menu_items: hide soft-deleted rows ────────────────────────────

create or replace function public.search_menu_items(
  p_query text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  restaurant_id uuid,
  category_id uuid,
  name text,
  description text,
  price numeric,
  image_url text,
  is_veg boolean,
  is_available boolean,
  restaurant_name text,
  distance_km double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with origin as (
    select case
      when p_latitude is null or p_longitude is null then null
      else st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography
    end as g
  )
  select
    mi.id, mi.restaurant_id, mi.category_id, mi.name, mi.description,
    mi.price, mi.image_url, mi.is_veg, mi.is_available,
    r.name as restaurant_name,
    case
      when origin.g is null or r.location is null then null
      else (st_distance(r.location, origin.g) / 1000.0)::double precision
    end as distance_km
  from public.menu_items mi
  join public.restaurants r
    on r.id = mi.restaurant_id
   and r.is_active
  cross join origin
  where mi.is_available
    and mi.deleted_at is null
    and length(trim(p_query)) >= 2
    and (
      mi.name ilike '%' || trim(p_query) || '%'
      or mi.description ilike '%' || trim(p_query) || '%'
    )
  order by
    (mi.name ilike '%' || trim(p_query) || '%') desc,
    case
      when origin.g is null or r.location is null then null
      else st_distance(r.location, origin.g)
    end asc nulls last,
    mi.name asc
  limit greatest(coalesce(p_limit, 30), 1)
$$;
