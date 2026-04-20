-- ============================================================================
-- Phase 11 — Profile extras.
--
-- Adds optional columns to `public.profiles` so customers can fill in:
--   • gender + date_of_birth
--   • dietary preference (one of: veg | non-veg | eggetarian | vegan | jain)
--   • allergies (multi-select array)
--   • notification prefs (jsonb: order_updates, promos, event_reminders, whatsapp)
--
-- All columns are nullable. Existing rows are untouched. Re-runnable.
-- ============================================================================

alter table public.profiles
  add column if not exists gender              text,
  add column if not exists date_of_birth       date,
  add column if not exists avatar_url          text,
  add column if not exists dietary_preference  text,
  add column if not exists allergies           text[] default '{}',
  add column if not exists notification_prefs  jsonb  default '{}'::jsonb;

-- Light guardrail on dietary_preference — null allowed, any of a small set
-- otherwise. Drop + recreate so re-runs stay idempotent.
alter table public.profiles
  drop constraint if exists profiles_dietary_check;
alter table public.profiles
  add constraint profiles_dietary_check
  check (
    dietary_preference is null
    or dietary_preference in ('veg','non_veg','eggetarian','vegan','jain')
  );


-- Verify (manual)
-- select id, email, gender, date_of_birth, dietary_preference,
--        allergies, notification_prefs
--   from public.profiles
--  where id = auth.uid();
