# Banquet & Catering App

Flutter mobile app for planning events and booking catering — user plans their event, picks a menu, gets an itemised quote with GST. Admin manages the menu catalog, pricing, and incoming bookings.

## Stack

- **Flutter 3.19+** · Material 3 · Playfair Display + Inter (google_fonts)
- **Riverpod 2** · state management
- **go_router** · role-based routing guard
- **Supabase** · Postgres · Auth (phone OTP) · Realtime · Storage
- **Razorpay** · (Phase 6 — not wired yet)
- **Phosphor Icons** · **Skeletonizer** · **flutter_animate** · **Lottie**

## Run it

```bash
flutter pub get
```

### Option A — without Supabase (stub data, fastest for UI work)

```bash
flutter run
```

`AppConfig.hasSupabase` returns `false` → splash skips auth → user home loads with seeded in-memory menu + charges.

### Option B — with Supabase (recommended)

1. Copy the env template:
   ```bash
   cp env/dev.example.json env/dev.json
   ```
2. Open [env/dev.json](env/dev.json) and paste your keys from **Supabase Dashboard → Settings → API** (`Project URL` + `anon public`).
3. Run:
   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```

### Option C — VS Code (easiest daily flow)

Launch configs already live in [.vscode/launch.json](.vscode/launch.json). Press **F5** and pick **"Banquet · dev (Supabase)"**. Or pick **"no backend, stub data"** for UI-only work.

### ⚠️ Secrets hygiene

- `env/dev.json` is **gitignored** — never commit it.
- `env/dev.example.json` **is** committed as a template.
- Only ship the **`anon`** key in the app. The `service_role` key stays server-side (Edge Functions only).

## Backend setup

1. Create a Supabase project.
2. In the SQL editor, run [`supabase/schema.sql`](supabase/schema.sql) top to bottom.
3. In **Storage**, create buckets: `menu-images`, `restaurant-logos` (public read), `invoices` (private).
4. In **Auth → Providers**, enable **Phone** and wire your SMS provider (MSG91 / Twilio).
5. After signing up once via OTP, promote yourself to admin:
   ```sql
   update public.profiles set role = 'admin'
     where id = (select id from auth.users where phone = '+91XXXXXXXXXX');
   ```

## Architecture

The app follows a **layered, feature-first architecture** with unidirectional data flow and a clean split between UI, state, domain models, and data access. A stub-fallback pattern in every repository means the entire UI runs with or without a backend.

### Layer diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION (features/)                      │
│  splash · auth · user screens · admin screens                        │
│  Consumes providers → renders Material 3 widgets from shared/widgets │
└───────────────────────┬──────────────────────────────────────────────┘
                        │  watch / read (Riverpod)
┌───────────────────────▼──────────────────────────────────────────────┐
│                     STATE (shared/providers/)                        │
│  authProvider · currentProfileProvider · cartProvider                │
│  eventDraftProvider · menuProvider · chargesProvider · repoProviders │
└───────────────────────┬──────────────────────────────────────────────┘
                        │  calls
┌───────────────────────▼──────────────────────────────────────────────┐
│                     DOMAIN (data/models/)                            │
│  UserProfile · MenuItem · Restaurant · EventDraft · Order · ...      │
│  Plain Dart value objects — fromMap / toMap                          │
└───────────────────────┬──────────────────────────────────────────────┘
                        │  used by
┌───────────────────────▼──────────────────────────────────────────────┐
│                  DATA ACCESS (data/repositories/)                    │
│  AuthRepo · MenuRepo · OrderRepo · ChargesRepo · EventRepo           │
│  if AppConfig.hasSupabase → Supabase client                          │
│  else                     → in-memory seed (offline UI dev)          │
└───────────────────────┬──────────────────────────────────────────────┘
                        │  HTTPS / Realtime / Storage
┌───────────────────────▼──────────────────────────────────────────────┐
│                   BACKEND (Supabase project)                         │
│  Postgres (RLS) · Auth (phone OTP) · Realtime · Storage buckets      │
└──────────────────────────────────────────────────────────────────────┘
```

### Module responsibilities

| Layer | Folder | Responsibility |
| --- | --- | --- |
| Bootstrap | [lib/main.dart](lib/main.dart), [lib/app.dart](lib/app.dart) | `ProviderScope`, Supabase init, `MaterialApp.router`, theme wiring |
| Core | [lib/core/](lib/core/) | env flags, theme, constants, `go_router` + role guard, utils |
| Data — models | [lib/data/models/](lib/data/models/) | Immutable value objects; `fromMap` / `toMap` Supabase serialization |
| Data — repos | [lib/data/repositories/](lib/data/repositories/) | Single source of truth for every table; Supabase + stub fallback |
| State | [lib/shared/providers/](lib/shared/providers/) | Riverpod providers — auth, profile, cart, event draft, menu, charges |
| UI kit | [lib/shared/widgets/](lib/shared/widgets/) | Reusable widgets (AppCard, PrimaryButton, PriceRow, StatusBadge, …) |
| Features | [lib/features/](lib/features/) | Feature-first screens grouped by role: `splash`, `auth`, `user`, `admin` |

### Data flow — placing a booking

```
User taps "Confirm Booking" on Checkout
   │
   ▼
cartProvider + eventDraftProvider + chargesProvider  ──┐
                                                       │  aggregated by
OrderRepo.createOrder(order, items)  ◄─────────────────┘
   │
   ├─ Supabase insert into `orders` + `order_items` (RLS: owner = auth.uid())
   │
   ▼
Realtime stream (myOrdersStream) pushes row into "My Events"
   │
   ▼
Admin sees new row on Admin Orders (subscribed to same table)
   │
   ▼
Admin updates status → Realtime pushes status back to user's Order Detail
```

### Routing & role guard

[lib/core/router/](lib/core/router/) defines every route under `AppRoutes`. A single `redirect` callback reads `currentProfileProvider`:

- no session → `/login`
- session + `role=user` trying to hit admin route → redirect to `/home`
- session + `role=admin` trying to hit user route → redirect to `/admin`
- session + no profile row yet → `/login` (auth trigger will create the row)

### Backend architecture

- **Auth** — phone OTP. An `on_auth_user_created` trigger inserts a matching row into `public.profiles` (role defaults to `user`).
- **Tables** — `profiles`, `menu_categories`, `restaurants`, `menu_items`, `charges_config` (singleton id=1), `events`, `orders`, `order_items`.
- **RLS** — every table enabled; admin writes gated by `public.is_admin(auth.uid())`; users can only read/write their own `orders`/`events`.
- **Realtime** — `orders` and `events` broadcast to subscribed clients for live status.
- **Storage** — `menu-images`, `restaurant-logos` (public), `invoices` (private).

See [supabase/schema.sql](supabase/schema.sql) for the full DDL + policies.

## Folder structure

```
lib/
├── main.dart                     // ProviderScope + Supabase init
├── app.dart                      // MaterialApp.router + theme
├── core/
│   ├── config/                   // env flags
│   ├── constants/                // colors, sizes, text styles
│   ├── router/                   // go_router + AppRoutes + role guard
│   ├── supabase/                 // client init
│   ├── theme/                    // Material 3 ThemeData
│   └── utils/                    // formatters, validators
├── data/
│   ├── models/                   // UserProfile, MenuItem, Order, EventDraft, ...
│   └── repositories/             // Supabase-backed + stub fallbacks
├── shared/
│   ├── providers/                // Riverpod providers (auth, cart, event, menu, charges, repos)
│   └── widgets/                  // AppCard, PrimaryButton, PriceRow, StatusBadge, CategoryChip, ...
└── features/
    ├── splash/
    ├── auth/                     // login, OTP
    ├── user/screens/             // home, event, menu, cart, checkout, success, my events, order detail
    └── admin/screens/            // home, orders, menu, charges
```

## Core flow

```
Splash → (auth check)
    ├─ no session → Login → OTP → profiles row created → route by role
    └─ has session → route by role
            ├─ role=user  → User Home → Plan Event → Menu → Cart → Checkout → Success
            └─ role=admin → Admin Home → {Orders | Menu | Charges}
```

## Charges & totals

All computed client-side from `charges_config` + cart:

```
food_cost       = Σ(price × qty)
delivery_charge = Σ(unique_restaurants.delivery_charge)
subtotal        = food_cost + banquet_charge + delivery_charge
                  + buffet_setup + service_boy_cost
                  + water_bottle_cost + platform_fee
gst             = subtotal × gst_percent / 100
total_payable   = subtotal + gst
```

## What's next

- Phase 6 — Razorpay integration + Edge Function for webhook verification
- Phase 7 — FCM push notifications on status changes
- Phase 8 — admin menu item CRUD (image pick + compress + upload)
- Admin analytics dashboard (revenue, upcoming events, cancellations)
