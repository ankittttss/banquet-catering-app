#!/usr/bin/env node
// ============================================================================
//  Dawat — run SQL migrations against Supabase Postgres.
//  Uses direct pg connection (bypasses RLS) so it can run seed + admin SQL.
//
//  Usage:
//    SUPABASE_DB_URL="postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres" \
//      node tool/run_migrations.mjs
//
//  Or set SUPABASE_DB_PASSWORD and we'll construct the URL from env/dev.json.
// ============================================================================
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const { Client } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..');

const MIGRATIONS = [
  'supabase/addresses_migration.sql',
  'supabase/seed_more_restaurants.sql',
  'supabase/menu_images.sql',
];

function resolveConnectionString() {
  if (process.env.SUPABASE_DB_URL) return process.env.SUPABASE_DB_URL;

  const env = JSON.parse(
    readFileSync(join(repoRoot, 'env', 'dev.json'), 'utf8'),
  );
  const url = new URL(env.SUPABASE_URL);
  const ref = url.hostname.split('.')[0];
  const password = process.env.SUPABASE_DB_PASSWORD;
  if (!password) {
    throw new Error(
      'Set SUPABASE_DB_URL or SUPABASE_DB_PASSWORD.\n' +
        'Get the password from Supabase Dashboard > Project Settings > Database.',
    );
  }
  // Direct (session-mode) connection on port 5432.
  return `postgresql://postgres:${encodeURIComponent(password)}@db.${ref}.supabase.co:5432/postgres?sslmode=require`;
}

async function run() {
  const connectionString = resolveConnectionString();
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
  });

  console.log('-> connecting to Supabase Postgres...');
  await client.connect();
  console.log('   connected.');

  for (const rel of MIGRATIONS) {
    const abs = join(repoRoot, rel);
    console.log(`\n-> running ${rel}`);
    const sql = readFileSync(abs, 'utf8');
    try {
      await client.query(sql);
      console.log(`   OK`);
    } catch (e) {
      console.error(`   FAILED: ${e.message}`);
      throw e;
    }
  }

  await client.end();
  console.log('\nAll migrations complete.');
}

run().catch((e) => {
  console.error('\nMigration failed:', e.message);
  process.exit(1);
});
