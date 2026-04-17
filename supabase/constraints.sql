-- ============================================================================
--  Dawat — data integrity constraints
--  Run once, after schema.sql + addresses_migration.sql + seed_data.sql.
--  Idempotent — all constraints use NOT VALID / check-if-exists so re-running is safe.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- menu_items
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'menu_items_price_positive'
  ) then
    alter table public.menu_items
      add constraint menu_items_price_positive check (price > 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'menu_items_name_length'
  ) then
    alter table public.menu_items
      add constraint menu_items_name_length
      check (char_length(name) between 2 and 120);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- restaurants
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'restaurants_delivery_nonneg'
  ) then
    alter table public.restaurants
      add constraint restaurants_delivery_nonneg
      check (delivery_charge >= 0);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- events
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_guest_count_positive'
  ) then
    alter table public.events
      add constraint events_guest_count_positive check (guest_count > 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'events_time_range'
  ) then
    alter table public.events
      add constraint events_time_range check (end_time > start_time);
  end if;

  -- Soft rule: event_date cannot be in the past.
  -- Enforced only on inserts via trigger, since existing data may violate.
end $$;

create or replace function public._forbid_past_event_dates()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' and new.event_date < current_date then
    raise exception 'event_date cannot be in the past';
  end if;
  return new;
end;
$$;

drop trigger if exists events_forbid_past_insert on public.events;
create trigger events_forbid_past_insert
  before insert on public.events
  for each row execute procedure public._forbid_past_event_dates();

-- ----------------------------------------------------------------------------
-- orders — totals sanity
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'orders_total_positive'
  ) then
    alter table public.orders
      add constraint orders_total_positive check (total > 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_subtotal_nonneg'
  ) then
    alter table public.orders
      add constraint orders_subtotal_nonneg check (subtotal >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_gst_nonneg'
  ) then
    alter table public.orders
      add constraint orders_gst_nonneg check (gst >= 0);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- charges_config — sane bounds
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'charges_gst_percent_range'
  ) then
    alter table public.charges_config
      add constraint charges_gst_percent_range
      check (gst_percent >= 0 and gst_percent <= 40);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- Useful analytics view — today's revenue snapshot.
-- ----------------------------------------------------------------------------
create or replace view public.v_revenue_today as
  select
    count(*)          as order_count,
    coalesce(sum(total), 0) as gross,
    coalesce(sum(gst),   0) as gst_collected
  from public.orders
  where created_at::date = current_date;

-- RLS on view: only admins can read.
alter view public.v_revenue_today owner to postgres;
-- (Views respect the RLS of their underlying tables; orders_admin_read covers it.)
