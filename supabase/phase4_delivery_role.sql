-- ============================================================================
-- Phase 4 — add 'delivery' role + promote test users.
-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent).
-- ============================================================================
--
-- Two-step setup:
--   PART A — run now: widens the CHECK constraint + cleans up any broken
--            rows left over from earlier attempts.
--   PART B — run AFTER you sign up the three test accounts through the
--            app's Sign up screen, then edit the UPDATE statements with
--            those emails.
--
-- This avoids brittle hand-crafted inserts into auth.users (which differ
-- across Supabase versions and trigger "Database error querying schema"
-- on login).
-- ============================================================================


-- ============================================================================
-- PART A — run first.
-- ============================================================================

-- 1. Widen the role CHECK constraint to allow 'delivery'.
alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('user','admin','delivery'));

-- 2. Clean up any half-inserted rows from earlier seed attempts so they
--    don't block re-signup or poison the auth schema.
delete from public.profiles
 where email in ('user@dawat.test','admin@dawat.test','delivery@dawat.test');

delete from auth.identities
 where user_id in (
   select id from auth.users
    where email in ('user@dawat.test','admin@dawat.test','delivery@dawat.test')
 );

delete from auth.users
 where email in ('user@dawat.test','admin@dawat.test','delivery@dawat.test');


-- ============================================================================
-- PART B — run AFTER signing up your three accounts through the app.
--
-- In the app's Sign up screen, create three accounts (any emails + password
-- you like). Then edit the three UPDATE statements below with THOSE emails
-- and run them to assign roles.
--
-- Uncomment + edit before running.
-- ============================================================================

-- update public.profiles
--    set role = 'admin'
--  where email = 'YOUR_ADMIN_EMAIL_HERE';

-- update public.profiles
--    set role = 'delivery'
--  where email = 'YOUR_DELIVERY_EMAIL_HERE';

-- update public.profiles
--    set role = 'user'  -- already the default; this is just for completeness
--  where email = 'YOUR_USER_EMAIL_HERE';


-- ============================================================================
-- Verify
-- ============================================================================
-- select id, email, role from public.profiles order by role;
