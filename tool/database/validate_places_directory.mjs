import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(resolve('.dart_tool/sql_validation/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_user_meta_data jsonb DEFAULT '{}');
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT current_setting('request.jwt.claim.role',true) $$;
    GRANT USAGE ON SCHEMA auth,public TO anon,authenticated;`);
  // Supabase Storage tables are platform-owned; emulate their minimal schema locally.
  await db.exec(`CREATE SCHEMA storage;
    CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean);
    CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text);
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;`);
  const sql = (await readFile('docs/supabase_schema.sql','utf8')).replace('CREATE EXTENSION IF NOT EXISTS "pgcrypto";','');
  await db.exec(sql);
  await db.exec("UPDATE public.google_api_budgets SET request_limit=5000,used_units=800 WHERE sku='details_enterprise'");
  await db.exec("INSERT INTO public.places(place_id,name,state,category,latitude,longitude) VALUES ('ChITestDirectory','Example','Penang','Culture',5.4,100.3)");
  await db.exec(sql);
  const budget=(await db.query("SELECT request_limit,used_units FROM public.google_api_budgets WHERE sku='details_enterprise'")).rows[0];
  assert.equal(budget.request_limit,5000); assert.equal(budget.used_units,800);
  await db.exec('SET ROLE authenticated');
  const row = (await db.query("SELECT * FROM public.places_directory WHERE place_id='ChITestDirectory'")).rows[0];
  assert.equal(row.setting,'待审核');
  assert.equal(row.display_label,'Example');
  assert.equal(row.location_status,'已有位置');
  assert.ok(!JSON.stringify(row).includes('Saved Google place'));
  await assert.rejects(db.exec("UPDATE public.places_directory SET category='Food' WHERE place_id='ChITestDirectory'"));
  await db.exec('RESET ROLE; SET ROLE anon');
  await assert.rejects(db.query('SELECT * FROM public.places_directory'));
  await db.exec('RESET ROLE');
  const stored = (await db.query("SELECT name,latitude,longitude,google_fetched_at FROM public.places WHERE place_id='ChITestDirectory'")).rows[0];
  assert.equal(stored.name,'Example');
  assert.equal(stored.latitude,5.4);
  assert.ok(stored.google_fetched_at);
  await db.exec(`UPDATE public.places SET operating_hours='{"weekdayDescriptions":["Monday: 8–10"]}',rating=4.1 WHERE place_id='ChITestDirectory';
    UPDATE public.places SET operating_hours='{"weekdayDescriptions":["Monday: 9–11"]}',rating=4.7 WHERE place_id='ChITestDirectory';`);
  const latest=(await db.query("SELECT operating_hours,rating,name FROM public.places WHERE place_id='ChITestDirectory'")).rows[0];
  assert.equal(latest.operating_hours.weekdayDescriptions[0],'Monday: 9–11');
  assert.equal(Number(latest.rating),4.7); assert.equal(latest.name,'Example');
  assert.equal((await db.query("SELECT reloptions FROM pg_class WHERE oid='public.places_directory'::regclass")).rows[0].reloptions.includes('security_invoker=true'),true);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.places')).rows[0].n,1);
  console.log('PASS: repeated recovery, preserved data, readable directory, invoker RLS and read-only grants');
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally { await db.close(); }
