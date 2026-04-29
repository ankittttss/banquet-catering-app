-- ============================================================================
-- Phase 22 — Partner registration (banquet + restaurant via invite).
--
-- Existing model (Phase 5): admin creates a row in `partner_invites` → new
-- user signs up with that email → `handle_new_user` trigger auto-promotes
-- them to `role='delivery'`. We extend this to cover banquet and restaurant
-- partners, and have the trigger also create the venue / kitchen link.
--
-- Flow (for a new banquet):
--   1. Admin inserts partner_invites row with:
--        role_to_assign = 'banquet',
--        email          = 'newvenue@example.com',
--        name           = 'Venue Operator',
--        venue_name     = 'Lotus Gardens',
--        venue_address  = '...',
--        venue_capacity = 500
--   2. New user signs up in the Dawat Partner app with that email.
--   3. Trigger fires:
--        - promotes their profile to role='banquet'
--        - inserts a `banquet_venues` row owned by them
--        - marks the invite consumed
--
-- Flow (for a new restaurant):
--   1. Admin inserts partner_invites row with:
--        role_to_assign = 'restaurant',
--        email          = 'kitchen@example.com',
--        name           = 'Kitchen Operator',
--        restaurant_id  = <existing restaurants.id>  (kitchen they'll manage)
--   2. New user signs up.
--   3. Trigger promotes them + inserts `restaurant_staff(restaurant_id, profile_id)`.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. Extend partner_invites schema.
-- ============================================================================
alter table public.partner_invites
  add column if not exists role_to_assign text not null default 'delivery',
  add column if not exists venue_name     text,
  add column if not exists venue_address  text,
  add column if not exists venue_capacity int,
  add column if not exists restaurant_id  uuid
    references public.restaurants(id) on delete set null;

-- Widen the CHECK on role_to_assign. Drop + recreate to allow re-runs.
alter table public.partner_invites
  drop constraint if exists partner_invites_role_check;
alter table public.partner_invites
  add constraint partner_invites_role_check
  check (role_to_assign in ('delivery','banquet','restaurant','manager','service_boy'));

-- Phase 5 made `vehicle` / `vehicle_number` / `phone` NOT NULL because those
-- only made sense for delivery. Widen to allow banquet/restaurant invites
-- that skip them.
alter table public.partner_invites
  alter column vehicle        drop not null,
  alter column vehicle_number drop not null,
  alter column phone          drop not null;


-- ============================================================================
-- 2. Rewrite handle_new_user to dispatch on role_to_assign.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.partner_invites%rowtype;
  v_venue_id uuid;
begin
  select *
    into v_invite
    from public.partner_invites
   where lower(email) = lower(new.email)
     and consumed_at is null
   order by created_at desc
   limit 1;

  -- No invite → default customer signup.
  if v_invite.id is null then
    insert into public.profiles (id, phone, email)
    values (new.id, new.phone, new.email)
    on conflict (id) do nothing;
    return new;
  end if;

  -- Invite present: branch on role.
  case v_invite.role_to_assign
    when 'delivery' then
      insert into public.profiles
        (id, phone, email, name, role, vehicle, vehicle_number)
      values
        (new.id, coalesce(new.phone, v_invite.phone), new.email,
         v_invite.name, 'delivery',
         v_invite.vehicle, v_invite.vehicle_number)
      on conflict (id) do update
        set role           = 'delivery',
            name           = excluded.name,
            phone          = excluded.phone,
            vehicle        = excluded.vehicle,
            vehicle_number = excluded.vehicle_number;

    when 'banquet' then
      insert into public.profiles (id, phone, email, name, role)
      values (new.id, coalesce(new.phone, v_invite.phone), new.email,
              v_invite.name, 'banquet')
      on conflict (id) do update
        set role  = 'banquet',
            name  = excluded.name,
            phone = excluded.phone;

      -- Provision the banquet venue if the invite carried one.
      if v_invite.venue_name is not null then
        insert into public.banquet_venues
          (owner_profile_id, name, address, capacity, is_active)
        values (new.id, v_invite.venue_name, v_invite.venue_address,
                v_invite.venue_capacity, true)
        returning id into v_venue_id;
      end if;

    when 'restaurant' then
      insert into public.profiles (id, phone, email, name, role)
      values (new.id, coalesce(new.phone, v_invite.phone), new.email,
              v_invite.name, 'restaurant')
      on conflict (id) do update
        set role  = 'restaurant',
            name  = excluded.name,
            phone = excluded.phone;

      -- Link them to the kitchen specified on the invite.
      if v_invite.restaurant_id is not null then
        insert into public.restaurant_staff (restaurant_id, profile_id)
        values (v_invite.restaurant_id, new.id)
        on conflict (restaurant_id, profile_id) do nothing;
      end if;

    when 'manager' then
      insert into public.profiles (id, phone, email, name, role)
      values (new.id, coalesce(new.phone, v_invite.phone), new.email,
              v_invite.name, 'manager')
      on conflict (id) do update
        set role  = 'manager',
            name  = excluded.name,
            phone = excluded.phone;

    when 'service_boy' then
      insert into public.profiles
        (id, phone, email, name, role, reports_to_manager_id)
      values (new.id, coalesce(new.phone, v_invite.phone), new.email,
              v_invite.name, 'service_boy',
              v_invite.created_by) -- inviting manager becomes the supervisor
      on conflict (id) do update
        set role                  = 'service_boy',
            name                  = excluded.name,
            phone                 = excluded.phone,
            reports_to_manager_id = excluded.reports_to_manager_id;

    else
      -- Unknown role — fall back to customer.
      insert into public.profiles (id, phone, email)
      values (new.id, new.phone, new.email)
      on conflict (id) do nothing;
  end case;

  update public.partner_invites
     set consumed_at = now(),
         consumed_by = new.id
   where id = v_invite.id;

  return new;
end;
$$;


-- ============================================================================
-- 3. Usage cheat-sheet (copy-paste as needed).
-- ============================================================================
-- -- Invite a new banquet operator:
-- insert into public.partner_invites
--   (email, name, role_to_assign, venue_name, venue_address, venue_capacity)
-- values ('newvenue@example.com', 'Operator One', 'banquet',
--         'Lotus Gardens', 'Jubilee Hills, Hyderabad', 500);
--
-- -- Invite a restaurant operator tied to an existing kitchen:
-- insert into public.partner_invites
--   (email, name, role_to_assign, restaurant_id)
-- values ('kitchen@example.com', 'Kitchen One', 'restaurant',
--         (select id from public.restaurants limit 1));
--
-- -- Invite a manager:
-- insert into public.partner_invites (email, name, role_to_assign)
-- values ('newmanager@example.com', 'Manager Two', 'manager');
--
-- -- Invite a service boy (inviter becomes their manager via created_by):
-- insert into public.partner_invites (email, name, role_to_assign, created_by)
-- values ('newservice@example.com', 'Service Three', 'service_boy',
--         (select id from auth.users where email='manager1@dawat.test'));
--
-- -- After the invitee signs up, verify:
-- select role, reports_to_manager_id from public.profiles
--   where email = 'newmanager@example.com';
