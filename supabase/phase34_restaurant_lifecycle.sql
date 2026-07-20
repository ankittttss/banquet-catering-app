-- ============================================================================
-- Phase 34 — Restaurant lifecycle (draft / published / suspended / archived)
-- ----------------------------------------------------------------------------
-- 1. Adds status + lifecycle timestamp columns to public.restaurants.
-- 2. Backfills every currently-active row to 'published' (zero visible change
--    for customers — the 1,123 seed restaurants stay live).
-- 3. One BEFORE trigger that:
--      a. hard-blocks publishing an incomplete restaurant (the DB is the real
--         gate; the Flutter checklist is just UX),
--      b. keeps is_active in sync with status so the existing customer
--         queries and both geo RPCs (restaurants_near, restaurants_for_event)
--         keep working untouched,
--      c. stamps published_at / archived_at / updated_at.
-- 4. Storage policies for the restaurant-logos and menu-images buckets
--    (admin write, public read) — the buckets exist but had no policies,
--    so every upload failed.
-- 5. Index for the admin list (status filter + name ordering/search).
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ── 1) Columns ──────────────────────────────────────────────────────────────

alter table public.restaurants
  add column if not exists status          text not null default 'draft',
  add column if not exists cover_image_url text,
  add column if not exists published_at    timestamptz,
  add column if not exists archived_at     timestamptz,
  add column if not exists updated_at      timestamptz not null default now();

do $$ begin
  alter table public.restaurants
    add constraint restaurants_status_check
    check (status in ('draft', 'published', 'suspended', 'archived'));
exception when duplicate_object then null; end $$;

-- ── 2) Backfill (runs BEFORE the trigger exists, so no publish validation
--       fires against seed rows that have no cover image / etc.) ─────────────

update public.restaurants
   set status       = 'published',
       published_at = created_at
 where is_active
   and status = 'draft';

-- ── 3) Lifecycle trigger: publish gate + is_active sync + timestamps ────────

create or replace function public.restaurants_before_write()
returns trigger
language plpgsql
as $$
declare
  entering_published boolean :=
    new.status = 'published'
    and (tg_op = 'INSERT' or old.status is distinct from 'published');
begin
  -- a) Publish gate — refuse to publish an incomplete restaurant. Runs only
  --    on the transition INTO 'published', so edits to already-published
  --    seed rows (which pre-date these requirements) are not blocked.
  if entering_published then
    if coalesce(trim(new.name), '') = '' then
      raise exception 'Cannot publish: restaurant name is required.';
    end if;
    if new.price_per_plate is null or new.price_per_plate <= 0 then
      raise exception 'Cannot publish "%": price per plate is required.', new.name;
    end if;
    if new.min_guests is null or new.min_guests <= 0 then
      raise exception 'Cannot publish "%": minimum guests is required.', new.name;
    end if;
    if coalesce(trim(new.address), '') = ''
       or new.latitude is null
       or new.longitude is null then
      raise exception 'Cannot publish "%": address and map location are required.', new.name;
    end if;
    if new.logo_url is null and new.cover_image_url is null then
      raise exception 'Cannot publish "%": a logo or cover image is required.', new.name;
    end if;
    if not exists (
      select 1 from public.menu_items mi
      where mi.restaurant_id = new.id
        and mi.is_available
    ) then
      raise exception 'Cannot publish "%": add at least one available menu item first.', new.name;
    end if;
  end if;

  -- b) is_active mirrors status — single source of truth. Every existing
  --    customer read path filters is_active, so nothing else changes.
  new.is_active := (new.status = 'published');

  -- c) Lifecycle timestamps.
  if entering_published then
    new.published_at := now();
  end if;
  if new.status = 'archived'
     and (tg_op = 'INSERT' or old.status is distinct from 'archived') then
    new.archived_at := now();
  end if;
  -- Restoring out of archive clears the marker ("archived_at = currently
  -- archived since"); published_at intentionally keeps the latest publish.
  if tg_op = 'UPDATE'
     and old.status = 'archived'
     and new.status <> 'archived' then
    new.archived_at := null;
  end if;

  if tg_op = 'UPDATE' then
    new.updated_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists restaurants_before_write on public.restaurants;
create trigger restaurants_before_write
  before insert or update on public.restaurants
  for each row execute function public.restaurants_before_write();

-- ── 4) Storage: catalog image buckets (restaurant-logos, menu-images) ───────
-- The buckets already exist in this project (created manually, public), but
-- the on-conflict upsert makes this file self-contained for fresh setups.

insert into storage.buckets (id, name, public)
values ('restaurant-logos', 'restaurant-logos', true),
       ('menu-images',      'menu-images',      true)
on conflict (id) do nothing;

do $$ begin
  create policy "catalog_images_public_read" on storage.objects
    for select
    using (bucket_id in ('restaurant-logos', 'menu-images'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "catalog_images_admin_insert" on storage.objects
    for insert
    with check (
      bucket_id in ('restaurant-logos', 'menu-images')
      and public.is_admin(auth.uid())
    );
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "catalog_images_admin_update" on storage.objects
    for update
    using (
      bucket_id in ('restaurant-logos', 'menu-images')
      and public.is_admin(auth.uid())
    )
    with check (
      bucket_id in ('restaurant-logos', 'menu-images')
      and public.is_admin(auth.uid())
    );
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "catalog_images_admin_delete" on storage.objects
    for delete
    using (
      bucket_id in ('restaurant-logos', 'menu-images')
      and public.is_admin(auth.uid())
    );
exception when duplicate_object then null; end $$;

-- ── 5) Admin list index (status filter chips + name search/order) ───────────

create index if not exists restaurants_status_name_idx
  on public.restaurants (status, name);
