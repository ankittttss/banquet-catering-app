-- ============================================================================
-- Phase 29 — Order-item visibility for operators + assigned staff.
--
-- The operator booking-review and manager event-detail screens now
-- show a tap-to-expand list of menu items under each restaurant on
-- the booking. Existing order_items RLS only let the customer (owner)
-- and the admin SELECT — non-owners trying to read the items got back
-- an empty list and the expanded section looked broken.
--
-- This migration mirrors the orders / order_vendor_lots policies that
-- phase 27 already shipped: banquet operators can read items for
-- bookings at their venues, managers and service-boys can read items
-- for events they're staffed on. Both policies route through the
-- existing SECURITY DEFINER helpers from phase 27 so we don't
-- reintroduce the 42P17 recursion that phases 24/27 had to work
-- around.
--
-- Additive + idempotent: every policy drops the same name first and
-- nothing else is touched.
-- ============================================================================

drop policy if exists "order_items_banquet_read" on public.order_items;
create policy "order_items_banquet_read"
  on public.order_items for select
  using (public.is_order_venue_owner(order_items.order_id, auth.uid()));

drop policy if exists "order_items_assignee_read" on public.order_items;
create policy "order_items_assignee_read"
  on public.order_items for select
  using (public.is_order_assignee(order_items.order_id, auth.uid()));
