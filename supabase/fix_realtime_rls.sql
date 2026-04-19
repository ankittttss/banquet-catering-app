-- ============================================================================
-- Fix: Supabase Realtime times out when an RLS policy uses a security-definer
-- function (is_admin / is_delivery). Rewrite every such policy to use an
-- inline EXISTS against public.profiles — same semantics, works reliably in
-- Realtime's authorizer context.
--
-- Safe to re-run. Only changes policies, never data.
-- ============================================================================


-- ────────────── orders ──────────────
drop policy if exists "orders_admin_read" on public.orders;
create policy "orders_admin_read"
  on public.orders for select
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "orders_admin_update" on public.orders;
create policy "orders_admin_update"
  on public.orders for update
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  );


-- ────────────── order_items ──────────────
drop policy if exists "order_items_admin_read" on public.order_items;
create policy "order_items_admin_read"
  on public.order_items for select
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  );


-- ────────────── deliveries ──────────────
drop policy if exists "deliveries_admin_all" on public.deliveries;
create policy "deliveries_admin_all"
  on public.deliveries for all
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "deliveries_driver_read" on public.deliveries;
create policy "deliveries_driver_read"
  on public.deliveries for select
  using (
    (status = 'offered' and exists (
       select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'delivery'
     ))
    or driver_id = auth.uid()
  );

drop policy if exists "deliveries_driver_update" on public.deliveries;
create policy "deliveries_driver_update"
  on public.deliveries for update
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'delivery')
    and (driver_id = auth.uid() or (status = 'offered' and driver_id is null))
  )
  with check (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'delivery')
    and (driver_id = auth.uid() or driver_id is null)
  );


-- ────────────── partner_invites ──────────────
drop policy if exists "partner_invites_admin_rw" on public.partner_invites;
create policy "partner_invites_admin_rw"
  on public.partner_invites for all
  using (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p
             where p.id = auth.uid() and p.role = 'admin')
  );


-- ────────────── profiles (admin read all) ──────────────
-- This policy lives on `profiles` itself, so an inline EXISTS against
-- `profiles` would trigger RLS recursively (error 42P17). We must use the
-- SECURITY DEFINER `is_admin()` helper here — it bypasses RLS, so no loop.
-- (Using it ONLY on profiles is safe; profiles isn't streamed via Realtime
-- from a screen that depends on filter evaluation.)
drop policy if exists "profiles_admin_read_all" on public.profiles;
create policy "profiles_admin_read_all"
  on public.profiles for select
  using (public.is_admin(auth.uid()));


-- ────────────── replica identity (idempotent) ──────────────
alter table public.orders      replica identity full;
alter table public.deliveries  replica identity full;
alter table public.profiles    replica identity full;


-- ────────────── verify ──────────────
-- select tablename, policyname, cmd, qual from pg_policies
--   where schemaname = 'public'
--  order by tablename, policyname;
