-- ============================================================================
-- Phase 25 — Notify staff when they're assigned to an event.
--
-- On INSERT into event_assignments, write a row into `notifications` for the
-- assigned profile. The manager / service-boy home screens will see:
--   (a) their stream on `event_assignments` push the new row → list updates
--   (b) a persisted notification record for the /notifications feed
--
-- Also fires on event banquet_status transitions so customers learn when
-- their booking is accepted or declined.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. Widen the `notifications.kind` CHECK constraint.
-- ============================================================================
alter table public.notifications
  drop constraint if exists notifications_kind_check;

alter table public.notifications
  add constraint notifications_kind_check check (kind in (
    'order_placed','order_confirmed','order_preparing',
    'order_dispatched','order_delivered','order_cancelled',
    'driver_assigned','promo','system',
    -- Staffing pings (Phase 25):
    'manager_assigned','service_boy_assigned',
    -- Banquet inbox pings (Phase 25):
    'event_accepted','event_declined'
  ));


-- ============================================================================
-- 2. Trigger: when someone is assigned to an event, notify them.
-- ============================================================================
create or replace function public.handle_event_assignment_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event    record;
  v_venue    text;
begin
  select e.event_date, e.session, e.guest_count,
         coalesce(v.name, e.location) as venue_label
    into v_event
    from public.events e
    left join public.banquet_venues v on v.id = e.banquet_venue_id
   where e.id = new.event_id;

  v_venue := coalesce(v_event.venue_label, 'the event');

  if new.role_on_event = 'manager' then
    insert into public.notifications
      (user_id, kind, title, body, icon_name, accent_hex, bg_hex)
    values (
      new.profile_id,
      'manager_assigned',
      'New event to manage',
      format('%s · %s guests · %s',
             to_char(v_event.event_date, 'DD Mon YYYY'),
             v_event.guest_count,
             v_venue),
      'user_circle_gear', '#8B1E3F', '#FFF1F2'
    );
  elsif new.role_on_event = 'service_boy' then
    insert into public.notifications
      (user_id, kind, title, body, icon_name, accent_hex, bg_hex)
    values (
      new.profile_id,
      'service_boy_assigned',
      'You''ve been staffed on an event',
      format('%s · %s guests · %s',
             to_char(v_event.event_date, 'DD Mon YYYY'),
             v_event.guest_count,
             v_venue),
      'users', '#8B1E3F', '#FFF1F2'
    );
  end if;

  return new;
end $$;

drop trigger if exists trg_event_assignment_notify on public.event_assignments;
create trigger trg_event_assignment_notify
after insert on public.event_assignments
for each row execute function public.handle_event_assignment_notify();


-- ============================================================================
-- 3. Trigger: when banquet accepts/declines, notify the customer.
-- ============================================================================
create or replace function public.handle_banquet_status_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue_name text;
begin
  if old.banquet_status is not distinct from new.banquet_status then
    return new;
  end if;
  if new.banquet_status not in ('accepted','declined') then
    return new;
  end if;

  select name into v_venue_name
    from public.banquet_venues
   where id = new.banquet_venue_id;

  insert into public.notifications
    (user_id, kind, title, body, icon_name, accent_hex, bg_hex)
  values (
    new.user_id,
    case when new.banquet_status = 'accepted'
         then 'event_accepted' else 'event_declined' end,
    case when new.banquet_status = 'accepted'
         then 'Your event booking was accepted'
         else 'Your event booking was declined' end,
    format('%s at %s',
           to_char(new.event_date, 'DD Mon YYYY'),
           coalesce(v_venue_name, 'the venue')),
    case when new.banquet_status = 'accepted'
         then 'check_circle' else 'x_circle' end,
    case when new.banquet_status = 'accepted'
         then '#1BA672' else '#8B1E3F' end,
    case when new.banquet_status = 'accepted'
         then '#EAFAF1' else '#FFF1F2' end
  );

  return new;
end $$;

drop trigger if exists trg_banquet_status_notify on public.events;
create trigger trg_banquet_status_notify
after update on public.events
for each row execute function public.handle_banquet_status_notify();


-- ============================================================================
-- 4. Realtime: the notifications table is already published (phase 8),
--    no change needed. Client streams any inserted row.
-- ============================================================================

-- Verify (uncomment):
-- select kind, title, user_id, created_at
--   from public.notifications
--  order by created_at desc limit 10;
