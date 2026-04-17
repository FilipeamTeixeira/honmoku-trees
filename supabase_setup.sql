-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================

create table if not exists public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  role         text not null default 'editor' check (role in ('admin', 'editor')),
  display_name text,
  created_at   timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Admins can read all profiles"
  on public.profiles for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can update any profile"
  on public.profiles for update
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

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

create policy "Editors can submit changes"
  on public.pending_changes for insert
  with check (auth.uid() = submitted_by);

create policy "Editors can read own submissions"
  on public.pending_changes for select
  using (auth.uid() = submitted_by);

create policy "Admins can read all pending changes"
  on public.pending_changes for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can update pending changes"
  on public.pending_changes for update
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );


-- ============================================================
-- 3. HELPER FUNCTION — call via sb.rpc('get_my_role')
-- ============================================================

create or replace function public.get_my_role()
returns text as $$
  select role from public.profiles where id = auth.uid();
$$ language sql security definer;


-- ============================================================
-- 4. PROMOTE A USER TO ADMIN
-- Uncomment, replace the email, and run once.
-- ============================================================

-- update public.profiles
-- set role = 'admin'
-- where id = (
--   select id from auth.users where email = 'your-admin@email.com'
-- );