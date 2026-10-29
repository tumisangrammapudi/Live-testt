-- Panic Alert: profile editing setup.
-- Run once in Supabase -> SQL Editor.
-- BEFORE running: replace admin@example.com (4 places) with your real administrator email,
-- the same one you set as ADMIN_EMAIL in index.html.

-- 1. Phone columns and a row id (safe to run more than once)
alter table dependents add column if not exists registered_by_phone text not null default '';
alter table dependents add column if not exists dependent_phone text not null default '';
alter table dependents add column if not exists id uuid default gen_random_uuid();
update dependents set id = gen_random_uuid() where id is null;
create unique index if not exists dependents_id_key on dependents (id);

alter table dependents enable row level security;

-- 2. Anyone can register (always as "pending")
drop policy if exists "anyone can register" on dependents;
create policy "anyone can register" on dependents
  for insert to anon, authenticated
  with check (status = 'pending');

-- 3. Read: the administrator sees everything; a registrant sees only their own rows
drop policy if exists "admin reads all" on dependents;
create policy "admin reads all" on dependents
  for select to authenticated
  using ((auth.jwt() ->> 'email') = 'admin@example.com');

drop policy if exists "registrant reads own" on dependents;
create policy "registrant reads own" on dependents
  for select to authenticated
  using (lower(registered_by_email) = lower(auth.jwt() ->> 'email'));

-- 4. Update: the administrator edits everything; a registrant edits only their own rows
drop policy if exists "admin updates all" on dependents;
create policy "admin updates all" on dependents
  for update to authenticated
  using ((auth.jwt() ->> 'email') = 'admin@example.com')
  with check ((auth.jwt() ->> 'email') = 'admin@example.com');

drop policy if exists "registrant updates own" on dependents;
create policy "registrant updates own" on dependents
  for update to authenticated
  using (lower(registered_by_email) = lower(auth.jwt() ->> 'email'))
  with check (lower(registered_by_email) = lower(auth.jwt() ->> 'email'));

-- 5. Registrants can never change their approval status or their email.
create or replace function protect_registration_fields() returns trigger
language plpgsql as $$
begin
  if (auth.jwt() ->> 'email') is distinct from 'admin@example.com' then
    new.status := old.status;
    new.registered_by_email := old.registered_by_email;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_registration_fields on dependents;
create trigger protect_registration_fields
  before update on dependents
  for each row execute function protect_registration_fields();

-- 6. Public, name-only list of approved people for the neighbour suggestions.
-- Emails and phone numbers are NOT included.
drop view if exists approved_registry;
create view approved_registry as
  select distinct registered_by_name as name
  from dependents
  where status = 'approved' and coalesce(registered_by_name, '') <> '';
grant select on approved_registry to anon, authenticated;

-- 7. Magic-link sign-in (done in the Supabase dashboard, not SQL):
--    Authentication -> URL Configuration -> add your site address to "Redirect URLs":
--    https://tumisangrammapudi.github.io/Live-testt/
