-- ============================================================================
-- Phase 39 — Order status derives automatically from kitchen (lot) progress.
-- ----------------------------------------------------------------------------
-- Previously the customer-facing order status only moved when an ADMIN
-- manually changed it in the "Full orders manager" screen. With this trigger
-- the pipeline runs itself and that screen is retired:
--
--   any kitchen starts working            → order 'preparing'
--   every kitchen's food picked up        → order 'dispatched'
--   every kitchen's food delivered        → order 'delivered'
--   every kitchen cancelled               → order 'cancelled'
--
-- Cancelled lots are excluded from "every" so one dead kitchen doesn't block
-- the rest of the event. Status only ever moves FORWARD; terminal orders
-- (delivered/cancelled) are never touched. Timestamps are stamped by the
-- existing trg_orders_status; a cancellation cascades back to remaining lots
-- via orders_cancel_cascade (phase38) — re-entry is guarded by the terminal-
-- status check below.
--
-- Idempotent.
-- ============================================================================

create or replace function public.lots_progress_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current order_status;
  v_total int;
  v_cancelled int;
  v_delivered int;
  v_picked_or_done int;
  v_started int;
begin
  select order_status into v_current
  from orders where id = new.order_id;

  -- Terminal orders never move (also breaks the cascade re-entry cycle).
  if v_current is null or v_current in ('delivered', 'cancelled') then
    return new;
  end if;

  select
    count(*),
    count(*) filter (where status = 'cancelled'),
    count(*) filter (where status = 'delivered'),
    count(*) filter (where status in ('picked_up', 'delivered')),
    count(*) filter (where status in
      ('accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'delivered'))
  into v_total, v_cancelled, v_delivered, v_picked_or_done, v_started
  from order_vendor_lots
  where order_id = new.order_id;

  if v_total = 0 then
    return new;
  end if;

  if v_cancelled = v_total then
    update orders set order_status = 'cancelled' where id = new.order_id;
  elsif v_delivered + v_cancelled = v_total then
    update orders set order_status = 'delivered' where id = new.order_id;
  elsif v_picked_or_done + v_cancelled = v_total then
    if v_current in ('placed', 'confirmed', 'preparing') then
      update orders set order_status = 'dispatched' where id = new.order_id;
    end if;
  elsif v_started > 0 and v_current in ('placed', 'confirmed') then
    update orders set order_status = 'preparing' where id = new.order_id;
  end if;

  return new;
end;
$$;

drop trigger if exists lots_progress_order on public.order_vendor_lots;
create trigger lots_progress_order
  after update of status on public.order_vendor_lots
  for each row execute function public.lots_progress_order();
