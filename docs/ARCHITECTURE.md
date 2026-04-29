# Dawat — App Architecture

> Catering & banquet marketplace. Customers order curated event menus, the
> kitchen accepts, a delivery partner picks up and delivers against an OTP,
> and an admin oversees the whole flow.

---

## 1. At a glance

| Pillar | Choice |
|---|---|
| **Mobile client** | Flutter (single codebase → Android, iOS, Web) |
| **State management** | Riverpod |
| **Navigation** | go_router (role-based redirects) |
| **Backend** | Supabase — Postgres + Auth + Realtime + Storage |
| **Maps** | OpenStreetMap tiles via `flutter_map` (no billing) |
| **Geocoding** | Photon (Komoot, free, OSM-backed) |
| **Location matching** | PostGIS (`ST_DWithin`, `restaurants_near` RPC) |
| **Payments** | Razorpay (wired, will be activated in a later phase) |
| **Push notifications** | Planned (Firebase Cloud Messaging) |

Build flavors ship with `--dart-define-from-file=env/dev.json` so the same
codebase can boot against dev, staging and prod backends by swapping a single
config file.

---

## 2. Three personas, one codebase

The app boots every user into the same Flutter binary. Post-login, the
`go_router` redirect reads the user's `profiles.role` and sends them to the
correct home screen. The role is the gatekeeper — no admin URL can be reached
without `role='admin'`, no delivery URL without `role='delivery'`.

| Role | Home route | Can do |
|---|---|---|
| **Customer** | `/user` | Browse restaurants, build cart, place order, track, review |
| **Banquet** | `/banquet` | Receive event bookings for their venues, accept/decline, assign managers, manage equipment inventory |
| **Restaurant** | `/restaurant` | See vendor lots routed to their kitchens, advance prep status (pending → ready_for_pickup) |
| **Manager** | `/manager` | Run assigned events, pull service boys from reports, staff the event |
| **Service Boy** | `/service-boy` | See their event assignments, check in / check out |
| **Admin** | `/admin` | Oversee every role, tune charges/menu, book Porter, set roles |

Delivery is outsourced to **Porter** (external courier). The legacy
`/delivery` routes are admin-gated while we phase them out.

### 2.1 Partner registration (how a banquet / restaurant joins)

All operator roles land via the invite-consumption pattern introduced for
delivery partners (Phase 5) and widened in Phase 22. There is **no public
self-signup** for operator roles — admin pre-approves by inserting a row
in `partner_invites`, the prospect signs up, and the `handle_new_user`
trigger auto-promotes them.

| Operator | Invite payload | What the trigger does on signup |
|---|---|---|
| Banquet | `role_to_assign='banquet'` + `venue_name`, `venue_address`, `venue_capacity` | Promotes profile; creates a `banquet_venues` row owned by them. |
| Restaurant | `role_to_assign='restaurant'` + `restaurant_id` (kitchen they'll manage) | Promotes profile; inserts `restaurant_staff(restaurant_id, profile_id)`. |
| Manager | `role_to_assign='manager'` | Promotes profile. |
| Service boy | `role_to_assign='service_boy'` + `created_by` (their future manager) | Promotes profile; sets `reports_to_manager_id = created_by`. |
| Delivery | `role_to_assign='delivery'` + vehicle info | Promotes profile with vehicle metadata. |

Customers sign up the normal way (email/password or OTP) and land as
`role='customer'` by default — no invite required. The admin can upgrade
a customer to any operator role at any time via `profiles.role` update.
Cheat-sheet inserts live at the bottom of `phase22_partner_registration.sql`.

Role transitions are enforced on both sides: the Flutter router blocks
unauthorized navigation, and the Postgres RLS policies block unauthorized
data access — defense in depth.

---

## 3. High-level flow

```
Customer app                 Supabase backend                     Delivery app
────────────                 ────────────────                     ─────────────
  |                                 |                                 |
  | 1. browse + build cart          |                                 |
  |                                 |                                 |
  | 2. place order  ─────────────►  INSERT orders                     |
  |                                 │                                 |
  |                                 ▼                                 |
  |                          [trigger: auto_dispatch_on_order]        |
  |                                 │                                 |
  |                                 ▼                                 |
  |                          INSERT deliveries (status='offered')     |
  |                                 │                                 |
  |                                 │  Realtime broadcast ────────►  3. offer appears
  |                                 │                                 |  in driver's feed
  |                                 │                                 |
  |                                 │  ◄── accept offer ─────────────  4. driver taps
  |                                 │                                   "Accept"
  |  5. live status updates ◄────── │                                 |
  |     (Realtime on orders)        │                                 |
  |                                 │                                 |
  |                                 │  ◄── mark picked_up ───────────  6. picks up food
  |                                 │                                 |
  |                                 │  ◄── mark delivered + OTP ─────  7. hands over
  |                                 │                                 |
  |  ◄── review request             │                                 |
  |                                 │                                 |
  |  submit rating  ─────────────►  INSERT reviews                    |
  |                                 │                                 |
  |                                 ▼                                 |
  |                          [trigger: recompute restaurant rating]   |
```

Everything in the middle column happens in **Postgres**. Triggers and
functions keep the state machine correct even if the clients disagree.

---

## 4. Client structure

```
lib/
 ├── core/
 │   ├── config/app_config.dart          # env-based feature flags
 │   ├── constants/                      # colors, sizes, text styles
 │   ├── router/                         # go_router + route constants
 │   ├── services/photon_geocoder.dart   # address autocomplete
 │   ├── supabase/supabase_client.dart   # single SupabaseClient instance
 │   └── utils/                          # formatters, validators
 ├── data/
 │   ├── models/                         # plain Dart DTOs (Order, Restaurant, …)
 │   └── repositories/
 │       ├── <name>_repository.dart      # abstract contract
 │       ├── stub/stub_<name>.dart       # in-memory dev impl
 │       └── supabase/supabase_<name>.dart  # production impl
 ├── features/
 │   ├── auth/        # login, OTP
 │   ├── onboarding/  # 3-slide intro
 │   ├── splash/
 │   ├── user/        # customer-facing screens + widgets
 │   ├── admin/       # admin dashboards
 │   └── delivery/    # driver dashboards
 └── shared/
     ├── providers/   # Riverpod providers (cart, auth, filters, reviews…)
     └── widgets/     # cross-cutting UI (AppScaffold, EmptyState, etc.)
```

**SOLID repository pattern** — every backend-touching call goes through an
`abstract interface class` with a Supabase implementation and a stub. The
stub returns in-memory fixtures, which lets the team run the full UI without
any backend (perfect for demos, designers, or offline dev).

---

## 5. Backend — Supabase

### 5.1 Core tables

| Table | What it holds |
|---|---|
| `profiles` | 1:1 with `auth.users`. Holds `role` (`user` / `admin` / `delivery`), phone, email, and driver-specific fields (`vehicle`, `rating`, `is_online`, `latitude`, `longitude`). |
| `restaurants` | ~1,100 kitchens scraped from OpenStreetMap + seeded, with lat/lng, cuisines, min guest count, delivery ETA, rating, hero images. |
| `menu_categories` | Starters, Mains, Desserts, etc. |
| `menu_items` | ~23,000 dishes across all restaurants, each linked to one restaurant + category. Includes price, veg flag, image. |
| `events` | User's event booking: date, location, guest count, session (lunch/dinner). |
| `orders` | Financial record of an event: food cost, delivery charge, GST, totals, order status, payment status, FK to a restaurant. |
| `order_items` | Cart lines at time of order (menu_item, qty, price snapshot). |
| `deliveries` | Per-order delivery lifecycle (offered → accepted → picked_up → delivered), includes OTP, driver_id, timestamps. |
| `reviews` | Per-(user, order) rating + comment. A trigger keeps `restaurants.rating`/`ratings_count` in sync. |
| `user_addresses` | Saved customer addresses (home, work, etc.), with lat/lng for nearby search. |
| `partner_invites` | Admin-created invites so delivery partners can self-signup and auto-promote to `role='delivery'`. |
| `notifications` | In-app notifications, streamed to the user. |
| `charges` | Platform fee, buffet setup, service boy rate, GST % — all admin-tunable. |
| `event_tiers` | Budget / Standard / Premium bands. Drives the restaurant budget filter via `restaurants_for_event` RPC. |
| `order_vendor_lots` | One row per restaurant per order. Kitchens accept/prep their own slice independently while the customer sees one booking. |
| `banquet_venues` | Venues owned by a banquet operator. Events are routed here via `events.banquet_venue_id`. |
| `banquet_inventory` | Per-venue catalog of equipment the operator can sell on top of food cost (water bottles, setup, staff extras). |
| `restaurant_staff` | Many-to-many between a restaurant login and the kitchens they manage. |
| `event_assignments` | Manager + service boys on a given event. Unique-index enforces one manager per event; service boys check in/out on their own rows. |

### 5.2 Triggers — backend does the plumbing

| Trigger | Fires on | What it does |
|---|---|---|
| `on_auth_user_created` | `auth.users` INSERT | Creates the `profiles` row. If the email matches a `partner_invites` record, auto-promotes to `delivery`. |
| `trg_orders_auto_dispatch` | `orders` INSERT | Automatically creates a `deliveries` row with `status='offered'` so every online driver sees the offer in real time. |
| `trg_reviews_sync` | `reviews` INSERT/UPDATE/DELETE | Recomputes `restaurants.rating` + `ratings_count` so ratings are always current. |
| `trg_reviews_touch` | `reviews` UPDATE | Bumps `updated_at`. |

This is deliberate: the backend is the source of truth for the order→delivery
→review pipeline. Even if a client misbehaves, the data stays consistent.

### 5.3 Row-Level Security (RLS)

Every table has RLS enabled. Policies are simple and explicit:

- **Customers** can read and write only their own `orders`, `order_items`,
  `addresses`, `reviews`, `notifications`, and `profile`.
- **Admins** can read/update every order, see every profile, and manage
  `charges` and `partner_invites`.
- **Delivery partners** can read all `offered` deliveries (broadcast) plus
  any delivery assigned to them, and can update their own delivery's status.
- **Reviews** are publicly readable (so any customer sees restaurant
  reviews) but only the author can insert/edit/delete their own.

Admin-role checks use a `SECURITY DEFINER` function (`is_admin(uid)`) to
avoid the RLS recursion that would otherwise happen when a policy on
`profiles` references `profiles`.

### 5.4 Realtime subscriptions

Three tables are streamed to clients via `supabase_realtime`:

- `orders` → customer's "My orders" timeline
- `deliveries` → driver's offer feed + active delivery
- `profiles` → driver online/offline flips, stats updates

Each streamed table has `REPLICA IDENTITY FULL` so filtered subscriptions
(e.g., `.eq('status', 'offered')`) resolve against full-row data.

### 5.5 Geolocation & PostGIS

- Every `restaurant` and `user_address` has `latitude`/`longitude` columns
  plus a generated `geography` column.
- The `restaurants_near(lat, lng, radius_km)` RPC uses `ST_DWithin` to
  return restaurants ordered by distance from a point.
- When the customer sets an address with coordinates, the home screen
  automatically switches from "all restaurants" to "nearby only".

No Google Maps billing — tiles come from OpenStreetMap (free), and address
autocomplete uses Photon (free, OSM-backed).

---

## 6. Feature walkthroughs

### 6.1 Customer flow

1. **Onboarding** — 3 animated slides in 8 Indian languages.
2. **Sign in** — email + password (Google OAuth wired for later).
3. **Home** — restaurant cards sorted by distance from active address.
   Filters, cuisine chips, hero banners.
4. **Restaurant detail** — hero, stats strip (rating, ETA, min guests),
   offers carousel, menu grouped by category, reviews section.
5. **Cart** — deduplicated by `(menu_item, portion, spice, notes)`
   signature. Live totals with food cost + GST + delivery + buffet setup.
6. **Checkout** — pick event date/session, guest count, delivery address.
7. **Order success** — reference number, "View my events".
8. **My events** — live status timeline backed by Realtime.
9. **Order detail** — driver info, OTP (customer-facing), "rate order"
   card once delivered.
10. **Profile** — saved addresses, favorites, notifications, About,
    Help & Support, sign out.

### 6.2 Admin flow

1. **Home dashboard** — quick stats + links.
2. **Orders** — every booking, status badges, "Assign driver" button once
   the order is confirmed. One-tap status transitions.
3. **Menu** — restaurant + item management (image upload ready).
4. **Charges** — tune platform fee, service boy rate, GST %.
5. **Partners** — create `partner_invite` rows. The invited email, on
   signup, is auto-promoted to `delivery` by the DB trigger.

### 6.3 Delivery partner flow

1. **Signup** — through admin invite (trigger auto-promotes to delivery).
2. **Dashboard** — online/offline toggle, stats (deliveries, earnings,
   rating), today's deliveries.
3. **Incoming offer** — auto-pops as a 15-second countdown sheet when any
   new `deliveries` row with `status='offered'` streams in.
4. **Active delivery** — OSM map + route polyline, sliding sheet with
   steps, customer details, order items.
5. **Pickup checklist** — 5-item gate before marking picked up.
6. **Delivery OTP** — 4-digit OTP verified against `deliveries.delivery_otp`.
   Bumps driver's `total_deliveries` counter.
7. **Earnings** — daily/weekly/monthly breakdown.
8. **History** — past deliveries.

---

## 7. Dispatch model

Today, we use a **broadcast dispatch** model — the same one Zomato and
Swiggy use at their lower tiers:

1. Order is placed → trigger creates `deliveries` row with `status=offered`
   and `driver_id=null`.
2. Every online driver's app (subscribed via Realtime with an RLS filter)
   sees the offer immediately.
3. First driver to accept wins; the row's `driver_id` is set and `status`
   flips to `accepted`. Other drivers' copies disappear from their feeds.
4. Admin can override manually — the admin's "Assign driver" sheet updates
   the same row rather than creating a duplicate.

**What's not in yet (future work):**
- Distance-based scoring (pick the nearest driver)
- Offer timeout + re-broadcast if declined
- Batching (one driver carrying multiple nearby drops)
- Fairness rotation (avoid starvation of a driver)

---

## 8. Security model

| Layer | How it protects |
|---|---|
| **Router** | Blocks navigation to admin/delivery routes unless the user's `profiles.role` matches. |
| **RLS** | Every query at the DB level is filtered by the signed-in user's role — even if a client is tampered with, Postgres rejects unauthorized rows. |
| **Auth** | Passwords hashed with bcrypt. JWT tokens rotated by Supabase Auth. OTP flow ready for SMS-based sign-in. |
| **Tokens & secrets** | `service_role` key never ships in the client. The app only ever uses `anon` key + user JWT. Admin actions go through RLS, not key escalation. |
| **Storage** | Per-bucket RLS (to be tightened when menu image uploads go live). |

---

## 9. What's shipped

| Phase | Scope |
|---|---|
| 1 | Home screen, restaurants, categories, collections, favorites |
| 2 | Event booking, cart, checkout, orders |
| 3 | Order tracking with timeline, driver metadata, status transitions |
| 4 | 3-role system (`user`, `admin`, `delivery`) |
| 5 | Delivery partner backend — `deliveries` table, partner invites, admin-invite flow |
| 6 | PostGIS + geolocation: nearby restaurants, address autocomplete (Photon) |
| 7 | Seeded Hyderabad coordinates for demo restaurants |
| 8 | Stock images (Unsplash) for restaurants + menu items, realtime notifications |
| 9 | Ratings & reviews — table, trigger-computed aggregate, customer UI, restaurant UI |
| 10 | Mock drivers seeded + auto-dispatch trigger on order placement |
| 11 | Profile extras + resilient realtime streams, my-orders redesign |
| 12 | **Retire in-app delivery** — drop auto-dispatch trigger (Porter replaces it) |
| 13 | **5-role expansion** — `customer / banquet / restaurant / service_boy / manager / admin`; `banquet_venues`, `restaurant_staff`, `profiles.reports_to_manager_id`; role-gated router |
| 14 | **Event tiers + budget filter** — `event_tiers` seeded Budget/Standard/Premium; `restaurants_for_event` RPC filters kitchens by per-guest price band + radius |
| 15 | **Multi-vendor cart + per-guest qty** — `order_vendor_lots` (per-kitchen slice of an order, own status machine); `order_items.qty_per_guest`; checkout totals scale by `events.guest_count` |
| 16 | **Banquet inbox** — `events.banquet_venue_id` + `banquet_event_status`; inbox screen with accept/decline; `banquet_inventory` catalog |
| 17 | **Event staffing** — `event_assignments` (manager + service boys per event); manager pulls from `reports_to_manager_id`; service boy check-in/out |
| 18 | **Porter handoff** — `deliveries` repurposed with `porter_booking_id`, `porter_tracking_url`, `vendor_lot_id`; one booking per lot |

---

## 10. What's next (proposed roadmap)

1. **Payments** — activate Razorpay, add webhook → mark order `paid`.
2. **Real-time order tracking (customer)** — map of the driver's live
   location + ETA for the order in progress.
3. **Push notifications (FCM)** — status changes + "driver near you".
4. **Favorites wired** — heart icons persist to a `favorites` table.
5. **Promo codes + first-order discount.**
6. **Analytics dashboard (admin)** — orders/day, GMV, top restaurants,
   refund rate.
7. **Restaurant self-serve onboarding** — apply → admin approves → live.
8. **i18n** — beyond the onboarding ticker; live translations for the app.
9. **Release readiness** — Sentry crash reporting, Firebase Analytics,
   icons, splash config, Play Store signing, CI.

---

## 11. Environments

| Env | Branch | Supabase project | Domain |
|---|---|---|---|
| **Production** | `main` | *(prod)* | *(tbd)* |
| **Development** | `ankit/dev`, `rishi/dev` | dev | localhost / preview |

Branch protection on `main`: PR required (no direct push), no force push,
no deletions. Everyday work happens on feature branches, merged via PR.

---

## 12. Running locally

```bash
# One-time
flutter pub get

# Dev run (connects to the Supabase project defined in env/dev.json)
flutter run -d chrome --web-port=8080 --dart-define-from-file=env/dev.json

# Dev run without backend (stub repositories, in-memory data)
flutter run -d chrome --web-port=8080
```

SQL migrations live under `supabase/`. Apply them in order in the Supabase
SQL Editor — each file is idempotent and safe to re-run.
