-- Scratch Score — initial schema
-- Offline-first sync model: every user-owned table carries user_id (cascade on auth delete),
-- updated_at (bumped by trigger, drives delta pull), and deleted_at (soft-delete tombstones).
-- Row Level Security scopes every row to its owner.

-- ---------------------------------------------------------------------------
-- Helper: bump updated_at on every UPDATE
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  home_course_id uuid,
  handicap numeric(4,1),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Auto-create a profile row on signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------------
-- courses
-- ---------------------------------------------------------------------------
create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  city text,
  region text,
  country text,
  external_ref text,                 -- for a future course-import API
  hole_count int not null default 18 check (hole_count in (9, 18)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.tee_sets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  name text not null,
  color text,
  rating numeric(4,1),
  slope int,
  total_yardage int,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.holes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  hole_number int not null check (hole_number between 1 and 18),
  par int not null check (par between 3 and 6),
  handicap_index int check (handicap_index between 1 and 18),  -- stroke index
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (course_id, hole_number)
);

create table if not exists public.tee_hole_yardages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tee_set_id uuid not null references public.tee_sets(id) on delete cascade,
  hole_number int not null check (hole_number between 1 and 18),
  yardage int,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tee_set_id, hole_number)
);

-- ---------------------------------------------------------------------------
-- rounds + hole_scores
-- ---------------------------------------------------------------------------
create table if not exists public.rounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id),
  tee_set_id uuid references public.tee_sets(id),
  course_name text,                  -- denormalized snapshot for offline list rendering
  played_on date not null default current_date,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'in_progress'
    check (status in ('in_progress', 'completed', 'abandoned')),
  format text not null default 'eighteen'
    check (format in ('eighteen', 'frontNine', 'backNine')),
  notes text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.hole_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  round_id uuid not null references public.rounds(id) on delete cascade,
  hole_number int not null check (hole_number between 1 and 18),
  shots_to_zone int check (shots_to_zone between 0 and 30),   -- Row A
  shots_in_zone int check (shots_in_zone between 0 and 30),   -- Row B (includes putts)
  putts int check (putts between 0 and 20),                   -- Row D (breakdown of B)
  penalty_strokes int not null default 0 check (penalty_strokes between 0 and 20),
  up_and_down_attempted boolean not null default false,
  up_and_down_made boolean not null default false,
  long_putt_made boolean not null default false,
  -- Row C (total) is derived (A + B) — intentionally NOT stored.
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (round_id, hole_number)
);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['profiles','courses','tee_sets','holes','tee_hole_yardages','rounds','hole_scores']
  loop
    execute format('drop trigger if exists set_updated_at on public.%I;', t);
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute procedure public.set_updated_at();',
      t
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Indexes to keep delta-pull (updated_at) fast
-- ---------------------------------------------------------------------------
create index if not exists idx_courses_updated on public.courses(user_id, updated_at);
create index if not exists idx_tee_sets_updated on public.tee_sets(user_id, updated_at);
create index if not exists idx_holes_updated on public.holes(user_id, updated_at);
create index if not exists idx_yardages_updated on public.tee_hole_yardages(user_id, updated_at);
create index if not exists idx_rounds_updated on public.rounds(user_id, updated_at);
create index if not exists idx_hole_scores_updated on public.hole_scores(user_id, updated_at);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.courses           enable row level security;
alter table public.tee_sets          enable row level security;
alter table public.holes             enable row level security;
alter table public.tee_hole_yardages enable row level security;
alter table public.rounds            enable row level security;
alter table public.hole_scores       enable row level security;

-- profiles keyed on id (== auth.uid())
create policy "profiles_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles_delete" on public.profiles for delete using (auth.uid() = id);

-- All other tables keyed on user_id. Generated symmetrically.
do $$
declare t text;
begin
  foreach t in array array['courses','tee_sets','holes','tee_hole_yardages','rounds','hole_scores']
  loop
    execute format('create policy "%1$s_select" on public.%1$I for select using (auth.uid() = user_id);', t);
    execute format('create policy "%1$s_insert" on public.%1$I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "%1$s_update" on public.%1$I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
    execute format('create policy "%1$s_delete" on public.%1$I for delete using (auth.uid() = user_id);', t);
  end loop;
end;
$$;
