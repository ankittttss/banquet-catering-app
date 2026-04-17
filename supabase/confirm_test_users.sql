-- ============================================================================
-- Option A — manually confirm the 2 existing test users so they can sign in.
-- Run this in Supabase SQL Editor once. Safe to re-run.
-- ============================================================================

update auth.users
   set email_confirmed_at = coalesce(email_confirmed_at, now()),
       confirmed_at       = coalesce(confirmed_at, now())
 where email in (
   'ankitsaini7829@gmail.com',
   'ankitsaini955831@gmail.com'
 );

-- Also make sure a public.profiles row exists for each (trigger should have
-- created them, but this is a safety net).
insert into public.profiles (id, email)
select u.id, u.email
  from auth.users u
 where u.email in (
   'ankitsaini7829@gmail.com',
   'ankitsaini955831@gmail.com'
 )
   and not exists (select 1 from public.profiles p where p.id = u.id);


-- ============================================================================
-- Option B — turn off the "Confirm email" requirement entirely (recommended
-- for development). Cannot be done via SQL — do it in the dashboard:
--   Authentication → Sign In / Providers → Email → toggle OFF "Confirm email"
-- ============================================================================


-- ============================================================================
-- Verify
-- ============================================================================
-- select email, email_confirmed_at from auth.users;
-- select id, role, email from public.profiles;
