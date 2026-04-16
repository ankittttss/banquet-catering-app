#!/usr/bin/env node
/**
 * Dawat — Menu image uploader
 *
 * Downloads the curated Unsplash images for every seeded menu item,
 * uploads them to the Supabase Storage bucket `menu-images`, then
 * updates `menu_items.image_url` to point at the bucket's public URL.
 *
 * Why?  Hosting images in your own bucket means:
 *  - No dependency on Unsplash uptime or CDN
 *  - Stable URLs you control
 *  - Private-bucket option for paid-only menus later
 *
 * Usage:
 *   1. cd tool && npm i @supabase/supabase-js
 *   2. export SUPABASE_URL=https://<your-project>.supabase.co
 *   3. export SUPABASE_SERVICE_ROLE_KEY=<service-role-key from Dashboard → Settings → API>
 *      (service_role bypasses RLS — keep it private, never ship in the app)
 *   4. node upload_menu_images.mjs
 *
 * Safe to re-run: it skips items whose image_url already points to your bucket.
 */

import { createClient } from '@supabase/supabase-js';

const BUCKET = 'menu-images';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    '❌ Missing env. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running.',
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Same curated map as supabase/menu_images.sql — duplicated here on purpose
// so this script is self-contained and can be re-run independently.
const IMAGES = [
  // Spice Route Catering
  ['Masala Lemonade', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc'],
  ['Rose Sharbat', 'https://images.unsplash.com/photo-1546171753-97d7676e4602'],
  ['Aam Panna', 'https://images.unsplash.com/photo-1601924994987-69e26d50dc26'],
  ['Paneer Tikka', 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8'],
  ['Hara Bhara Kebab', 'https://images.unsplash.com/photo-1601050690597-df0568f70950'],
  ['Murg Malai Kebab', 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0'],
  ['Mutton Seekh Kebab', 'https://images.unsplash.com/photo-1633321702518-7feccafb94d5'],
  ['Dal Makhani', 'https://images.unsplash.com/photo-1585937421612-70a008356fbe'],
  ['Paneer Butter Masala', 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7'],
  ['Hyderabadi Biryani', 'https://images.unsplash.com/photo-1589302168068-964664d93dc0'],
  ['Veg Biryani', 'https://images.unsplash.com/photo-1596797038530-2c107229654b'],
  ['Butter Naan', 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46'],
  ['Gulab Jamun', 'https://images.unsplash.com/photo-1601303516361-77e7e2d77eec'],
  ['Gajar Halwa', 'https://images.unsplash.com/photo-1625398407937-2fa21d36f11f'],
  // Royal Banquet Kitchen
  ['Coconut Cooler', 'https://images.unsplash.com/photo-1600271886742-f049cd451bba'],
  ['Jaljeera Shot', 'https://images.unsplash.com/photo-1544145945-f90425340c7e'],
  ['Galouti Kebab', 'https://images.unsplash.com/photo-1606491956689-2ea866880c84'],
  ['Tandoori Mushroom', 'https://images.unsplash.com/photo-1625944525903-f58dfa6cf4db'],
  ['Kashmiri Rogan Josh', 'https://images.unsplash.com/photo-1574484284002-952d92456975'],
  ['Paneer Lababdar', 'https://images.unsplash.com/photo-1628294895950-9805252327bc'],
  ['Lucknowi Biryani', 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a'],
  ['Jeera Rice', 'https://images.unsplash.com/photo-1596797038530-2c107229654b'],
  ['Rasmalai', 'https://images.unsplash.com/photo-1589249137304-08b68dc4b019'],
  ['Shahi Tukda', 'https://images.unsplash.com/photo-1630410333262-a51e884dee25'],
  ['Pickle & Papad Platter', 'https://images.unsplash.com/photo-1565557623262-b51c2513a641'],
  ['Raita', 'https://images.unsplash.com/photo-1626132647523-66f5bf380027'],
  // Coastal Kitchen
  ['Sol Kadhi', 'https://images.unsplash.com/photo-1572449043416-55f4685c9bb7'],
  ['Prawn Koliwada', 'https://images.unsplash.com/photo-1625943553852-781c6dd46faa'],
  ['Gobi 65', 'https://images.unsplash.com/photo-1606491956689-2ea866880c84'],
  ['Goan Fish Curry', 'https://images.unsplash.com/photo-1626804475297-41608ea09aeb'],
  ['Malabar Paratha', 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46'],
  ['Bebinca', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c'],
];

function slugify(s) {
  return s
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

async function downloadImage(url) {
  const full = `${url}?w=800&q=80&auto=format&fit=crop`;
  const res = await fetch(full);
  if (!res.ok) throw new Error(`fetch ${res.status} ${res.statusText}`);
  const buf = Buffer.from(await res.arrayBuffer());
  return buf;
}

async function uploadOne(itemName, url) {
  const filename = `${slugify(itemName)}.jpg`;

  // Find the menu_items row for this item (first match if duplicates).
  const { data: items, error: qErr } = await supabase
    .from('menu_items')
    .select('id, image_url')
    .eq('name', itemName);
  if (qErr) throw qErr;
  if (!items?.length) {
    console.log(`  ⊘  skip (not in DB): ${itemName}`);
    return;
  }

  // Idempotency — skip if already bucket-hosted.
  const alreadyInBucket = items.every(
    (r) => r.image_url && r.image_url.includes(`/object/public/${BUCKET}/`),
  );
  if (alreadyInBucket) {
    console.log(`  ✓  already in bucket: ${itemName}`);
    return;
  }

  // Download + upload
  console.log(`  ↓  downloading ${itemName}…`);
  const bytes = await downloadImage(url);
  console.log(`  ↑  uploading ${filename} (${(bytes.length / 1024) | 0} KB)…`);
  const { error: upErr } = await supabase.storage
    .from(BUCKET)
    .upload(filename, bytes, {
      contentType: 'image/jpeg',
      upsert: true,
    });
  if (upErr) throw upErr;

  const {
    data: { publicUrl },
  } = supabase.storage.from(BUCKET).getPublicUrl(filename);

  // Update every row (could be in multiple restaurants).
  for (const row of items) {
    const { error: updErr } = await supabase
      .from('menu_items')
      .update({ image_url: publicUrl })
      .eq('id', row.id);
    if (updErr) throw updErr;
  }
  console.log(`  ✅ ${itemName}  →  ${publicUrl}`);
}

async function main() {
  console.log(`Dawat — uploading ${IMAGES.length} menu images to "${BUCKET}"`);
  let ok = 0;
  let fail = 0;
  for (const [name, url] of IMAGES) {
    try {
      await uploadOne(name, url);
      ok++;
    } catch (e) {
      fail++;
      console.error(`  ✖  ${name}: ${e.message}`);
    }
  }
  console.log(`\nDone.  ${ok} ok, ${fail} failed.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
