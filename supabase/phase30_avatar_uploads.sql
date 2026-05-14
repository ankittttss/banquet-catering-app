-- ============================================================================
-- Phase 30 — Avatar uploads.
--
-- Spins up a public-read storage bucket for profile photos and locks down
-- writes to the owning user. The `profiles.avatar_url` column already
-- exists (Phase 11), so we don't touch the table — just storage + RLS.
--
-- Convention: one file per user at `avatars/{auth.uid()}.jpg`. The client
-- upserts with the user's UUID as the filename, so a new upload overwrites
-- the previous one — no orphan files, no GC needed. The client appends a
-- `?v={timestamp}` query string to the URL it stores so the CDN cache
-- doesn't stick after a re-upload.
--
-- Safe to re-run.
-- ============================================================================

-- 1. Bucket — public read, ~2 MB cap (client re-encodes to ~100 KB JPEG
--    so this is a safety net, not the expected size).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2 * 1024 * 1024,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;


-- 2. Policies — drop + recreate so re-runs stay idempotent.
drop policy if exists avatars_public_read   on storage.objects;
drop policy if exists avatars_self_insert   on storage.objects;
drop policy if exists avatars_self_update   on storage.objects;
drop policy if exists avatars_self_delete   on storage.objects;

-- Anyone (including anon) can read avatar files — they're meant to be
-- embedded in any UI surface that shows a profile.
create policy avatars_public_read on storage.objects
  for select
  using (bucket_id = 'avatars');

-- Owner-write: the file is stored at `{uid}.jpg` at the root of the
-- bucket, so we match against the part before the first dot rather than
-- against `storage.foldername()` (which returns NULL for root-level
-- files and silently breaks the policy).
create policy avatars_self_insert on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );

create policy avatars_self_update on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );

create policy avatars_self_delete on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );


-- Verify (manual):
-- select id, public, file_size_limit, allowed_mime_types
--   from storage.buckets where id = 'avatars';
--
-- select policyname, cmd
--   from pg_policies
--  where schemaname = 'storage' and tablename = 'objects'
--    and policyname like 'avatars_%';
