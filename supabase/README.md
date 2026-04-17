# Dawat — Supabase migrations

Run these files **in order** from the Supabase SQL editor. Each is idempotent — safe to re-run if you're unsure.

| # | File | Purpose |
|---|---|---|
| 1 | [schema.sql](schema.sql) | Core tables (profiles, restaurants, menu_items, events, orders, etc.) + RLS + is_admin helper + seed categories |
| 2 | [seed_data.sql](seed_data.sql) | 3 sample restaurants + menu items |
| 3 | [seed_more_restaurants.sql](seed_more_restaurants.sql) | +3 more restaurants + logo URLs |
| 4 | [menu_images.sql](menu_images.sql) | Sets `image_url` on every menu item (Unsplash CDN) |
| 5 | [addresses_migration.sql](addresses_migration.sql) | `user_addresses` table + `upsert_address()` RPC |
| 6 | [constraints.sql](constraints.sql) | Data integrity CHECK constraints + past-date trigger + revenue view |

## After migrations

### Enable Email auth

**Auth → Providers → Email** → enable → **turn OFF "Confirm email"** for dev.

### (Optional) Enable Google OAuth

**Auth → Providers → Google** → paste Client ID + Secret from Google Cloud Console. Redirect URI: `https://<your-project>.supabase.co/auth/v1/callback`.

### Promote yourself to admin

After your first sign-in, run:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users order by created_at desc limit 1);
```

### (Optional) Upload menu images to your bucket

If you want images hosted in your `menu-images` bucket instead of loaded from Unsplash:

```bash
cd tool
npm install
export SUPABASE_URL=...
export SUPABASE_SERVICE_ROLE_KEY=...   # from Settings → API
node upload_menu_images.mjs
```

## Storage buckets to create

- `menu-images` (public)
- `restaurant-logos` (public)
- `invoices` (private — future use)

---

## Still to build (backend)

These are not shipped yet — they appear in our chat's roadmap:

- Atomic order-placement RPC (events + orders + order_items in one transaction)
- Payment webhook Edge Function (Razorpay)
- Invoice PDF Edge Function
- Reviews + ratings table
- Promo codes table + redemption Edge Function
- FCM push Edge Function
- Audit logs
- Email notification Edge Function (booking confirmation)

Each is a self-contained migration to add when you get to it.
