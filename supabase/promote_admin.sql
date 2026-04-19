-- ============================================================================
-- Promote a specific account to admin.
-- Replace the email below with YOUR admin login email, then run once.
-- ============================================================================

-- 1. Inspect current state.
select id, email, role
  from public.profiles
 where email = 'REPLACE_ME@example.com';

-- 2. Promote.
update public.profiles
   set role = 'admin'
 where email = 'REPLACE_ME@example.com';

-- 3. Verify.
select id, email, role
  from public.profiles
 where email = 'REPLACE_ME@example.com';
