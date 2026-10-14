-- Ecos de Papel / Migración 02
-- Ejecutar DESPUÉS de supabase/schema.sql en una instalación nueva.
-- Ya se aplicó a Supabase Ecos de Papel (bioaztyrkmingcziolot) en octubre de 2026.
-- No ejecutarla en UMBRA Reader.

create index if not exists idx_fragments_author on public.fragments(author_id);
create index if not exists idx_lectodinamicas_creator on public.lectodinamicas(created_by);
create index if not exists idx_readings_reader on public.readings(reader_id);
create index if not exists idx_votes_submission_dynamic on public.votes(submission_id,dynamic_id);
create index if not exists idx_votes_voter on public.votes(voter_id);
create index if not exists idx_works_author on public.works(author_id);

create or replace function private.is_ecos_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;
revoke all on function private.is_ecos_admin() from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_ecos_admin() to authenticated;

create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.profiles(id) on delete cascade,
  assigned_by uuid not null references public.profiles(id),
  new_role text not null check (new_role in ('member','moderator','admin')),
  created_at timestamptz not null default now(),
  check (target_id <> assigned_by)
);
create index idx_role_assignments_target on public.role_assignments(target_id, created_at);
create index idx_role_assignments_assigner on public.role_assignments(assigned_by);
alter table public.role_assignments enable row level security;
revoke all on public.role_assignments from anon, authenticated;
grant select on public.role_assignments to authenticated;
grant insert (target_id, assigned_by, new_role) on public.role_assignments to authenticated;

create policy "Only administrators see role changes" on public.role_assignments
for select to authenticated using ((select private.is_ecos_admin()));
create policy "Only administrators assign other members roles" on public.role_assignments
for insert to authenticated
with check (
  assigned_by = (select auth.uid())
  and target_id <> (select auth.uid())
  and (select private.is_ecos_admin())
);

create or replace function private.apply_ecos_role_assignment()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.profiles set role = new.new_role where id = new.target_id;
  return new;
end;
$$;
revoke all on function private.apply_ecos_role_assignment() from public, anon, authenticated;
create trigger ecos_apply_role after insert on public.role_assignments
for each row execute function private.apply_ecos_role_assignment();

alter table public.lectodinamica_images alter column image_url set not null;
