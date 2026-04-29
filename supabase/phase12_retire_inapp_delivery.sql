-- ============================================================================
-- Phase 12 — Retire in-app delivery dispatch.
--
-- Porter (external) replaces the in-app driver model. We:
--   1. Drop the auto-dispatch trigger so new orders don't create `deliveries`
--      rows pointing at mock drivers.
--   2. Leave the `deliveries` table in place (Phase 17 will repurpose it as
--      a Porter booking record — one row per vendor lot).
--   3. Leave the mock driver profile rows in place for now. Phase 13 will
--      migrate `role='delivery'` rows to the new role enum; a separate
--      cleanup step can purge mock accounts if desired.
--
-- Safe to re-run.
-- ============================================================================

drop trigger if exists trg_orders_auto_dispatch on public.orders;

-- Keep the function around for reference, but make it a no-op so any stale
-- trigger recreations don't start re-dispatching.
create or replace function public.auto_dispatch_on_order()
returns trigger
language plpgsql
as $$
begin
  -- Intentionally a no-op. Dispatch now happens via Porter (Phase 17).
  return new;
end $$;
