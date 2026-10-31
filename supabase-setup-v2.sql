-- Panic Alert: profile editing setup (v2, fitted to your existing "dependents" table).
-- Administrator email is already filled in: kaelo9224@gmail.com
-- Run once in Supabase -> SQL Editor: paste everything, then tap Run.

-- Let the registration form insert without the other design's required columns
alter table public.dependents alter column client_id drop not null;
alter table public.dependents alter column name set default '';
alter table public.dependents alter column phone set default '';

-- Phone columns
alter table public.dependents add column if not exists registered_by_phone text not null default '';
alter table public.dependents add column if not exists dependent_phone text not null default '';

alter table public.dependents enable row level security;

-- Replace the open insert policy with one that forces "pending"
drop policy if exists "Allow anonymous registration" on public.dependents;
drop policy if exists "anyone can register" on public.dependents;
create policy "anyone can register" on public.dependents
  for insert to anon, authenticated
  with check (status = 'pending');

-- Administrator: read and update everything
drop policy if exists "admin reads all" on public.dependents;
create policy "admin reads all" on public.dependents
  for select to authenticated
  using ((auth.jwt() ->> 'email') = 'kaelo9224@gmail.com');

drop policy if exists "admin updates all" on public.dependents;
create policy "admin updates all" on public.dependents
  for update to authenticated
  using ((auth.jwt() ->> 'email') = 'kaelo9224@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'kaelo9224@gmail.com');

-- Registrants: read and update only their own rows
drop policy if exists "registrant reads own" on public.dependents;
create policy "registrant reads own" on public.dependents
  for select to authenticated
  using (lower(registered_by_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "registrant updates own" on public.dependents;
create policy "registrant updates own" on public.dependents
  for update to authenticated
  using (lower(registered_by_email) = lower(auth.jwt() ->> 'email'))
  with check (lower(registered_by_email) = lower(auth.jwt() ->> 'email'));

-- Registrants can never change their approval status or email
create or replace function public.protect_registration_fields() returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (auth.jwt() ->> 'email') is distinct from 'kaelo9224@gmail.com' then
    new.status := old.status;
    new.registered_by_email := old.registered_by_email;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_registration_fields on public.dependents;
create trigger protect_registration_fields
  before update on public.dependents
  for each row execute function public.protect_registration_fields();

-- Public name-only list of approved people (no emails or phones)
drop view if exists public.approved_registry;
create view public.approved_registry as
  select distinct registered_by_name as name
  from public.dependents
  where status = 'approved' and coalesce(registered_by_name, '') <> '';
grant select on public.approved_registry to anon, authenticated;
