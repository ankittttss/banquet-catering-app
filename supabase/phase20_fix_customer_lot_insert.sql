-- ============================================================================
-- Phase 20 — Let customers insert their own vendor lots at checkout.
--
-- Phase 15 shipped SELECT policies on `order_vendor_lots` for customers /
-- restaurant staff / admin, but no INSERT policy for customers. Without it,
-- `supabase_order_repository.placeOrder()` fails with an RLS violation the
-- moment it tries to write the per-restaurant lot rows.
--
-- Fix: customer may insert a lot that belongs to an order they own.
-- Safe to re-run.
-- ============================================================================

drop policy if exists "lots_owner_insert" on public.order_vendor_lots;
create policy "lots_owner_insert"
  on public.order_vendor_lots for insert
  with check (
    exists (
      select 1 from public.orders o
       where o.id = order_id and o.user_id = auth.uid()
    )
  );

-- While we're here: the events RLS policy for customers (`events_owner_rw`)
-- covers INSERT/UPDATE via USING, but banquet venue routing adds a foreign
-- key that RLS might block if the venue policies are mis-ordered. Verify
-- customers can still write events with a non-null banquet_venue_id.
-- No policy changes needed — `events_owner_rw` already uses user_id.

-- Also defensive: order_items RLS — customers can already insert because
-- they own the parent order, but verify the policy still exists after the
-- Phase 15 additions.
-- (No changes needed if schema.sql `order_items_owner_rw` is intact.)
