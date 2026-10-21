// Isolated PostgreSQL validation: no production database or credentials are used.
// Install: pnpm --dir .dart_tool/sql_validation add @electric-sql/pglite
// Run: node tool/database/validate_schema.mjs
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(resolve('.dart_tool/sql_validation/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb DEFAULT '{}');
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.role', true),'') $$;
    GRANT USAGE ON SCHEMA auth,public TO anon,authenticated;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon,authenticated;
  `);
  const original = await readFile('docs/supabase_schema.sql', 'utf8');
  // PGlite has gen_random_uuid built in; the optional Supabase extension is unavailable here.
  const sql = original.replace('CREATE EXTENSION IF NOT EXISTS "pgcrypto";', '');
  if (process.argv.includes('--legacy-duplicates')) {
    // Reproduce the deployed schema before it enforced one subtype row per place.
    await db.exec(sql.slice(0,sql.indexOf('CREATE TABLE IF NOT EXISTS public.indoor_places')));
    for (const name of ['indoor_places','outdoor_places']) {
      const definition=sql.match(new RegExp(`CREATE TABLE IF NOT EXISTS public.${name} \\([\\s\\S]*?\\n\\);`))[0];
      await db.exec(definition.replace('NOT NULL UNIQUE REFERENCES','NOT NULL REFERENCES'));
    }
    await db.exec(`
      INSERT INTO public.places(place_id,name,state,category,latitude,longitude)
      VALUES ('legacy-indoor','Museum','Penang','Culture',5.4,100.3),('legacy-outdoor','Park','Penang','Nature',5.4,100.3);
      INSERT INTO public.indoor_places(id,place_id,is_air_conditioned,max_capacity) VALUES
        ('50000000-0000-4000-8000-000000000001','legacy-indoor',true,100),
        ('50000000-0000-4000-8000-000000000002','legacy-indoor',false,200),
        ('50000000-0000-4000-8000-000000000003','legacy-indoor',true,null);
      INSERT INTO public.outdoor_places(place_id,is_rain_sensitive,weather_condition) VALUES
        ('legacy-outdoor',true,'Dry only'),('legacy-outdoor',false,'Cloudy');
      COMMIT;
    `);
  }
  await db.exec(sql);
  await db.exec(sql);
  console.log('PASS: recovery schema executes twice');
  assert.equal((await db.query("SELECT relrowsecurity FROM pg_class WHERE oid='recovery.place_subtype_duplicates'::regclass")).rows[0].relrowsecurity,true);
  if (process.argv.includes('--legacy-duplicates')) {
    assert.equal((await db.query("SELECT * FROM public.indoor_places WHERE place_id='legacy-indoor'")).rows.length,1);
    assert.equal((await db.query("SELECT * FROM public.outdoor_places WHERE place_id='legacy-outdoor'")).rows.length,1);
    const archive=(await db.query('SELECT source_table,row_data FROM recovery.place_subtype_duplicates')).rows;
    assert.equal(archive.length,5);
    assert.deepEqual(archive.filter(r=>r.source_table==='indoor_places').map(r=>r.row_data.max_capacity).sort(),[100,200,null].sort());
    assert.equal((await db.query("SELECT max_capacity FROM public.indoor_places WHERE place_id='legacy-indoor'")).rows[0].max_capacity,100);
    assert.equal((await db.query("SELECT count(*)::int AS count FROM public.places WHERE place_id LIKE 'legacy-%'")).rows[0].count,2);
    await assert.rejects(db.exec("SET ROLE anon; SELECT * FROM recovery.place_subtype_duplicates"));
    await db.exec('RESET ROLE');
    await assert.rejects(db.exec("SET ROLE authenticated; SELECT * FROM recovery.place_subtype_duplicates"));
    await db.exec('RESET ROLE');
    console.log('PASS: legacy duplicates consolidated; all five original rows archived once and inaccessible to app roles');
    // Unknown references must stop consolidation without deleting related data.
    await db.exec(`
      CREATE TABLE public.test_subtype_reference (subtype_id uuid REFERENCES public.indoor_places(id) ON DELETE CASCADE);
      INSERT INTO public.test_subtype_reference VALUES ('50000000-0000-4000-8000-000000000001');
      DROP INDEX public.idx_unique_indoor_place_id;
      INSERT INTO public.indoor_places(place_id,max_capacity) VALUES ('legacy-indoor',300);
    `);
    await assert.rejects(db.exec(sql), /another table references its rows/);
    await db.exec('ROLLBACK');
    assert.equal((await db.query("SELECT * FROM public.indoor_places WHERE place_id='legacy-indoor'")).rows.length,2);
    assert.equal((await db.query('SELECT * FROM public.test_subtype_reference')).rows.length,1);
    assert.equal((await db.query('SELECT * FROM recovery.place_subtype_duplicates')).rows.length,5);
    await db.exec('DROP TABLE public.test_subtype_reference');
    await db.exec(sql);
    console.log('PASS: unknown references abort the transaction and preserve original rows');
  }
  await db.exec(`GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO anon,authenticated;`);
  const a='10000000-0000-4000-8000-000000000001';
  const b='10000000-0000-4000-8000-000000000002';
  await db.query(`INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
    ($1,'a@test.example','{"full_name":"A","role":"admin"}'),($2,'b@test.example','{"full_name":"B"}')`,[a,b]);
  assert.equal((await db.query('SELECT role FROM public.profiles WHERE user_id=$1',[a])).rows[0].role,'user');
  console.log('PASS: registration metadata cannot grant admin');
  async function asUser(uid, role='authenticated') {
    await db.exec('RESET ROLE');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,false), set_config('request.jwt.claim.role',$2,false)",[uid,role]);
    await db.exec(`SET ROLE ${role}`);
  }
  const tripId='20000000-0000-4000-8000-000000000001';
  const dayId='30000000-0000-4000-8000-000000000001';
  const payload={itinerary_id:tripId,user_id:a,title:'Private A',destination_state:'Kuala Lumpur',
    total_cost:40,is_public:false,created_at:'2026-10-18T00:00:00Z',preferences:{start_date:'2026-11-01'},
    daily_schedules:[{schedule_id:dayId,day_number:1,schedule_date:'2026-11-01',total_distance_km:2,
      itinerary_stops:[{id:'40000000-0000-4000-8000-000000000001',place_id:'test-place',
        place_name:'Test museum',category:'Culture',latitude:3.15,longitude:101.71,stop_order:1,
        arrival_time:'09:00:00',departure_time:'10:00:00',snapshot:{estimated_cost:40}}]}]};
  await asUser(a);
  await db.query('SELECT public.save_itinerary($1::jsonb)',[JSON.stringify(payload)]);
  await db.query('SELECT public.save_itinerary($1::jsonb)',[JSON.stringify(payload)]);
  assert.equal((await db.query('SELECT * FROM public.itineraries')).rows.length,1);
  assert.equal((await db.query('SELECT * FROM public.itinerary_stops')).rows.length,1);
  assert.equal((await db.query('SELECT schedule_date::text FROM public.daily_schedules')).rows[0].schedule_date,'2026-11-01');
  console.log('PASS: authenticated atomic save, stable-ID retry, dates, and child records');
  await assert.rejects(db.query("UPDATE public.profiles SET role='admin' WHERE user_id=$1",[a]));
  assert.equal((await db.query("UPDATE public.places SET name='tampered' WHERE place_id='test-place' RETURNING *")).rows.length,0);
  await asUser(b);
  for (const table of ['profiles','itineraries','daily_schedules','itinerary_stops']) {
    const rows=(await db.query(`SELECT * FROM public.${table}`)).rows;
    assert.equal(rows.length,table==='profiles'?1:0,table);
  }
  assert.equal((await db.query('DELETE FROM public.itineraries WHERE itinerary_id=$1 RETURNING *',[tripId])).rows.length,0);
  await assert.rejects(db.query('SELECT public.save_itinerary($1::jsonb)',[JSON.stringify({...payload,user_id:b})]));
  await assert.rejects(db.query(`INSERT INTO public.daily_schedules(schedule_id,itinerary_id,day_number,schedule_date)
    VALUES ('30000000-0000-4000-8000-000000000002',$1,2,'2026-11-02')`,[tripId]));
  console.log('PASS: account B cannot read, delete, overwrite, or append to account A private trip');
  await asUser(a);
  const invalid=structuredClone(payload);invalid.title='Must roll back';
  invalid.daily_schedules[0].itinerary_stops[0].arrival_time='invalid';
  await assert.rejects(db.query('SELECT public.save_itinerary($1::jsonb)',[JSON.stringify(invalid)]));
  assert.equal((await db.query('SELECT title FROM public.itineraries')).rows[0].title,'Private A');
  assert.equal((await db.query('SELECT * FROM public.itinerary_stops')).rows.length,1);
  console.log('PASS: failed child insert rolls back the complete save');
  await db.query('UPDATE public.itineraries SET is_public=true WHERE itinerary_id=$1',[tripId]);
  await asUser(b);
  assert.equal((await db.query('SELECT * FROM public.itineraries')).rows.length,1);
  assert.equal((await db.query("UPDATE public.itineraries SET title='tampered' RETURNING *")).rows.length,0);
  await asUser('', 'anon');
  assert.equal((await db.query('SELECT * FROM public.profiles')).rows.length,0);
  assert.equal((await db.query('SELECT * FROM public.itineraries')).rows.length,0);
  console.log('PASS: explicit public sharing is read-only; anonymous users cannot access private accounts');
  await assert.rejects(db.query("SELECT * FROM public.record_place_sync('Penang',120,8)"));
  await db.exec("RESET ROLE; SELECT set_config('request.jwt.claim.role','service_role',false)");
  await db.query("UPDATE public.profiles SET role='admin' WHERE user_id=$1",[a]);
  await asUser(a);
  const sync=(await db.query("SELECT * FROM public.record_place_sync('Penang',120,8)")).rows[0];
  assert.equal(sync.place_count,120);assert.equal(sync.request_count,8);
  assert.ok(sync.last_synced_at);
  await db.query("SELECT * FROM public.record_place_sync('Penang',125,9)");
  assert.equal((await db.query('SELECT * FROM public.place_sync_status')).rows.length,1);
  await assert.rejects(db.query("SELECT * FROM public.record_place_sync('Penang',-1,9)"));
  assert.equal((await db.query('SELECT * FROM public.place_sync_status')).rows[0].place_count,125);
  await asUser(b);
  assert.equal((await db.query('SELECT * FROM public.place_sync_status')).rows.length,0);
  await assert.rejects(db.query("SELECT * FROM public.record_place_sync('Penang',999,1)"));
  await asUser('', 'anon');
  assert.equal((await db.query('SELECT * FROM public.place_sync_status')).rows.length,0);
  console.log('PASS: sync history is admin-only, uses server time, updates by state and rejects invalid counts');
} finally { await db.close(); }
