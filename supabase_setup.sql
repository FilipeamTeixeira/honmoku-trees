-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================

create table if not exists public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  role         text not null default 'editor' check (role in ('admin', 'editor')),
  display_name text,
  created_at   timestamptz default now()
);

-- ============================================================
-- HELPER FUNCTION — must be defined before RLS policies that use it
-- ============================================================

create or replace function public.get_my_role()
returns text as $$
  select role from public.profiles where id = auth.uid();
$$ language sql security definer;

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Admins can read all profiles" on public.profiles;
drop policy if exists "Admins can update any profile" on public.profiles;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Admins can read all profiles"
  on public.profiles for select
  using (public.get_my_role() = 'admin');

create policy "Admins can update any profile"
  on public.profiles for update
  using (public.get_my_role() = 'admin');

-- Auto-create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role) values (new.id, 'editor');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ============================================================
-- 2. PENDING CHANGES TABLE
-- ============================================================

create table if not exists public.pending_changes (
  id           uuid default gen_random_uuid() primary key,
  submitted_by uuid references auth.users on delete set null,
  action       text not null check (action in ('add', 'edit', 'delete')),
  tree_id      uuid references public.trees(id) on delete set null,
  payload      jsonb,
  note         text,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by  uuid references auth.users on delete set null,
  reviewed_at  timestamptz,
  created_at   timestamptz default now()
);

alter table public.pending_changes enable row level security;

drop policy if exists "Editors can submit changes" on public.pending_changes;
drop policy if exists "Editors can read own submissions" on public.pending_changes;
drop policy if exists "Admins can read all pending changes" on public.pending_changes;
drop policy if exists "Admins can update pending changes" on public.pending_changes;

create policy "Editors can submit changes"
  on public.pending_changes for insert
  with check (auth.uid() = submitted_by);

create policy "Editors can read own submissions"
  on public.pending_changes for select
  using (auth.uid() = submitted_by);

create policy "Admins can read all pending changes"
  on public.pending_changes for select
  using (public.get_my_role() = 'admin');

create policy "Admins can update pending changes"
  on public.pending_changes for update
  using (public.get_my_role() = 'admin');


-- ============================================================
-- 3. PROMOTE A USER TO ADMIN
-- Uncomment, replace the email, and run once.
-- ============================================================

-- update public.profiles
-- set role = 'admin'
-- where id = (
--   select id from auth.users where email = 'your-admin@email.com'
-- );

-- ============================================================
-- 4. FOREIGN KEY FROM pending_changes TO profiles
-- Allows Supabase to resolve the relationship in queries.
-- Run this if you want to use the join syntax later.
-- ============================================================

alter table public.pending_changes
  drop constraint if exists pending_changes_submitted_by_fkey_profiles;

alter table public.pending_changes
  add constraint pending_changes_submitted_by_fkey_profiles
  foreign key (submitted_by) references public.profiles(id) on delete set null;