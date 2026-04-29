-- =============================================================================
-- phase26: split service tax from GST on the bill, switch service_boy_cost
-- semantics from "flat per event" to "per service boy" (multiplied by the
-- customer-chosen count at checkout).
--
-- Run order: any time after schema.sql.
-- =============================================================================

-- 1. New service_tax_percent column on the charges config (separate from GST).
alter table public.charges_config
  add column if not exists service_tax_percent numeric(5,2) not null default 5;

-- 2. Per-boy semantics: existing rows assumed a 5-7 boy crew baked in. Reset
--    to a sensible per-head price so the customer-side stepper produces
--    realistic totals.
update public.charges_config
   set service_boy_cost = 800
 where id = 1
   and service_boy_cost > 1500; -- only reset legacy "flat" values

-- 3. Allow customers to override the staffing count. Stored on orders so the
--    banquet team sees what was billed; nullable so legacy rows stay valid.
alter table public.orders
  add column if not exists service_boy_count integer;
