-- ============================================================================
-- Phase 18 — Porter delivery handoff.
--
-- The in-app dispatch pipeline (Phase 10, trigger retired in Phase 12) is
-- replaced by Porter (external courier). We repurpose `deliveries` from a
-- driver-facing offer feed into a lightweight Porter-booking record —
-- one row per vendor lot (or per order, if all lots ship together).
--
-- MVP — manual booking: admin pastes a Porter tracking URL + booking id.
-- V2 (not in this migration): Supabase Edge Function calls Porter's Create
-- Booking API and writes the row automatically when all lots hit
-- `ready_for_pickup`.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. Columns — add Porter-specific fields, keep legacy columns that we still
--    use (delivery_otp, distance_km, etc.). Drop the driver-specific ones
--    or just ignore them; leaving them minimises churn on the `deliveries`
--    read path while the old delivery screens are admin-gated.
-- ============================================================================
alter table public.deliveries
  add column if not exists vendor_lot_id    uuid
    references public.order_vendor_lots(id) on delete cascade,
  add column if not exists porter_booking_id text,
  add column if not exists porter_tracking_url text,
  add column if not exists porter_status       text,
  add column if not exists pickup_eta_minutes  int,
  add column if not exists porter_fare         numeric(10,2);

create index if not exists idx_deliveries_vendor_lot
  on public.deliveries(vendor_lot_id);


-- ============================================================================
-- 2. RLS — customer sees their own Porter booking, admin + restaurant staff
--    for the owning kitchen can see too.
-- ============================================================================
drop policy if exists "deliveries_owner_read"    on public.deliveries;
drop policy if exists "deliveries_staff_read"    on public.deliveries;
drop policy if exists "deliveries_admin_write"   on public.deliveries;

create policy "deliveries_owner_read"
  on public.deliveries for select
  using (
    exists (
      select 1 from public.orders o
       where o.id = order_id and o.user_id = auth.uid()
    )
  );

create policy "deliveries_staff_read"
  on public.deliveries for select
  using (
    exists (
      select 1 from public.order_vendor_lots lot
        join public.restaurant_staff rs
          on rs.restaurant_id = lot.restaurant_id
       where lot.id = deliveries.vendor_lot_id
         and rs.profile_id = auth.uid()
    )
  );

create policy "deliveries_admin_write"
  on public.deliveries for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- ============================================================================
-- 3. Keep the existing realtime publication membership for `deliveries`.
--    No-op if already subscribed.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.deliveries;
exception when duplicate_object then null; end $$;

alter table public.deliveries replica identity full;
