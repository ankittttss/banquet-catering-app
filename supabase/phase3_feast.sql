-- ============================================================================
--  Feast Phase 3 + 4 — Order Tracking / History / Notifications.
--  Idempotent; safe to re-run. Paste into Supabase SQL Editor → Run.
--
--  Adds:
--    1. orders: driver metadata + ETA + per-status timestamps for the tracker
--    2. notifications table (user-scoped, RLS) + realtime-ready
-- ============================================================================


-- ============================================================================
-- 1. ORDERS — driver + tracker metadata
-- ============================================================================

alter table public.orders
  add column if not exists driver_name    text,
  add column if not exists driver_phone   text,
  add column if not exists driver_rating  numeric(2,1),
  add column if not exists driver_avatar_hex text default '#EBF4FF',
  add column if not exists eta_minutes_min int,
  add column if not exists eta_minutes_max int,
  add column if not exists placed_at      timestamptz default now(),
  add column if not exists confirmed_at   timestamptz,
  add column if not exists preparing_at   timestamptz,
  add column if not exists dispatched_at  timestamptz,
  add column if not exists delivered_at   timestamptz,
  add column if not exists cancelled_at   timestamptz;

-- Auto-stamp transition timestamps when status flips.
create or replace function public.handle_order_status_transition()
returns trigger
language plpgsql
as $$
begin
  if old.order_status is distinct from new.order_status then
    case new.order_status
      when 'confirmed'  then new.confirmed_at  := coalesce(new.confirmed_at,  now());
      when 'preparing'  then new.preparing_at  := coalesce(new.preparing_at,  now());
      when 'dispatched' then new.dispatched_at := coalesce(new.dispatched_at, now());
      when 'delivered'  then new.delivered_at  := coalesce(new.delivered_at,  now());
      when 'cancelled'  then new.cancelled_at  := coalesce(new.cancelled_at,  now());
      else null;
    end case;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_status on public.orders;
create trigger trg_orders_status
  before update on public.orders
  for each row execute procedure public.handle_order_status_transition();


-- ============================================================================
-- 2. NOTIFICATIONS
-- ============================================================================

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  order_id    uuid references public.orders(id) on delete cascade,
  kind        text not null check (kind in (
    'order_placed','order_confirmed','order_preparing',
    'order_dispatched','order_delivered','order_cancelled',
    'driver_assigned','promo','system'
  )),
  title       text not null,
  body        text,
  icon_name   text default 'notifications',
  accent_hex  text default '#E23744',
  bg_hex      text default '#FFF1F2',
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user
  on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_unread
  on public.notifications(user_id) where read_at is null;

alter table public.notifications enable row level security;
drop policy if exists "notifications_owner_rw" on public.notifications;
create policy "notifications_owner_rw"
  on public.notifications for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ============================================================================
-- 3. Auto-create notifications on order events
-- ============================================================================

create or replace function public.handle_order_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- On order insert → "Order placed"
  if tg_op = 'INSERT' then
    insert into public.notifications
      (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
    values (new.user_id, new.id, 'order_placed',
            'Order placed',
            'We''ve received your booking. Confirmation coming soon.',
            'receipt_long', '#2B6CB0', '#EBF4FF');
    return new;
  end if;

  -- On order update with changed status → status-specific notification
  if tg_op = 'UPDATE' and old.order_status is distinct from new.order_status then
    case new.order_status
      when 'confirmed' then
        insert into public.notifications
          (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
        values (new.user_id, new.id, 'order_confirmed',
                'Order confirmed',
                'Your booking is confirmed. We''re getting started.',
                'check_circle', '#1BA672', '#EAFAF1');
      when 'preparing' then
        insert into public.notifications
          (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
        values (new.user_id, new.id, 'order_preparing',
                'Food is being prepared',
                'The kitchen has started on your order.',
                'local_fire_department', '#E5A100', '#FFF8E7');
      when 'dispatched' then
        insert into public.notifications
          (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
        values (new.user_id, new.id, 'order_dispatched',
                'Out for delivery',
                coalesce(new.driver_name, 'A driver') ||
                  ' is on the way with your order.',
                'delivery_dining', '#2B6CB0', '#EBF4FF');
      when 'delivered' then
        insert into public.notifications
          (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
        values (new.user_id, new.id, 'order_delivered',
                'Order delivered!',
                'Enjoy your event. Rate your experience when you have a sec.',
                'celebration', '#1BA672', '#EAFAF1');
      when 'cancelled' then
        insert into public.notifications
          (user_id, order_id, kind, title, body, icon_name, accent_hex, bg_hex)
        values (new.user_id, new.id, 'order_cancelled',
                'Order cancelled',
                'If this was unexpected, contact support.',
                'cancel', '#E23744', '#FFF1F2');
      else null;
    end case;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_notify_insert on public.orders;
create trigger trg_orders_notify_insert
  after insert on public.orders
  for each row execute procedure public.handle_order_notification();

drop trigger if exists trg_orders_notify_update on public.orders;
create trigger trg_orders_notify_update
  after update on public.orders
  for each row execute procedure public.handle_order_notification();


-- ============================================================================
-- 4. Mark notification(s) as read
-- ============================================================================

create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.notifications
     set read_at = coalesce(read_at, now())
   where id = p_id and user_id = auth.uid();
end;
$$;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.notifications
     set read_at = coalesce(read_at, now())
   where user_id = auth.uid() and read_at is null;
end;
$$;


-- ============================================================================
-- Verification (optional)
-- ============================================================================
-- select id, order_status, placed_at, dispatched_at, delivered_at
--   from public.orders order by created_at desc limit 5;
-- select kind, title, created_at from public.notifications
--   order by created_at desc limit 10;
