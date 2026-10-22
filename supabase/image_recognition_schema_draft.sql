-- REVIEW ONLY: do not run this file yet.
-- Purpose: first database structure for the Image Recognition module.
-- All catalogue rows should initially use status = 'draft'.

create table if not exists public.landmark_catalogue (
  id text primary key,
  name text not null,
  aliases text[] not null default '{}',
  description text not null,
  category text not null default 'landmark',
  address text,
  latitude double precision,
  longitude double precision,
  opening_hours text,
  estimated_visit_minutes integer,
  estimated_cost_myr numeric(10,2),
  image_url text,
  source_url text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  last_verified_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_catalogue (
  id text primary key,
  name text not null,
  aliases text[] not null default '{}',
  description text not null,
  visual_cues text,
  typical_area text,
  image_url text,
  source_url text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  last_verified_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recognition_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  input_type text not null check (input_type in ('camera', 'gallery', 'demo')),
  image_path text,
  detected_type text check (detected_type in ('landmark', 'food', 'unknown')),
  detected_name text,
  confidence numeric(5,4),
  catalogue_id text,
  result_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.landmark_catalogue enable row level security;
alter table public.food_catalogue enable row level security;
alter table public.recognition_history enable row level security;

-- Published catalogue data is readable by signed-in app users.
create policy "published landmarks are readable"
  on public.landmark_catalogue for select
  to authenticated
  using (status = 'published');

create policy "published foods are readable"
  on public.food_catalogue for select
  to authenticated
  using (status = 'published');

create policy "users can read their own recognition history"
  on public.recognition_history for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users can create their own recognition history"
  on public.recognition_history for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- Admin insert/update/delete policies will be added after the team confirms
-- how admin accounts are represented in app_metadata.
