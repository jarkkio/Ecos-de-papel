-- Ecos de Papel · Esquema inicial para proyecto SUPABASE EXCLUSIVO del club.
-- NO ejecutar en UMBRA Reader. Ejecutar una sola vez en SQL Editor de Ecos de Papel.
-- Requiere Supabase Postgres con auth.users y storage disponibles.
begin;
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Sin nombre' check (char_length(display_name) between 1 and 65),
  role text not null default 'member' check (role in ('admin','moderator','member')),
  bio text not null default '' check (char_length(bio) <= 370),
  wattpad_url text check (wattpad_url is null or wattpad_url ~* '^https?://'),
  other_url text check (other_url is null or other_url ~* '^https?://'),
  created_at timestamptz not null default now()
);
create table if not exists public.lectodinamicas (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id),
  title text not null check (char_length(title) between 1 and 100),
  theme text not null check (char_length(theme) between 1 and 65),
  prompt text not null check (char_length(prompt) between 1 and 1500),
  starter text not null check (char_length(starter) between 1 and 1200),
  stage text not null default 'upcoming' check (stage in ('upcoming','open','closed')),
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  constraint lectodinamica_dates_ok check (end_date is null or start_date is null or end_date >= start_date)
);
create table if not exists public.lectodinamica_images (
  id uuid primary key default gen_random_uuid(),
  dynamic_id uuid not null references public.lectodinamicas(id) on delete cascade,
  position integer not null check (position between 1 and 3),
  label text not null check (char_length(label) between 1 and 100),
  image_url text check (image_url is null or image_url ~* '^https?://'),
  unique(dynamic_id,position)
);
create table if not exists public.fragments (
  id uuid primary key default gen_random_uuid(),
  dynamic_id uuid not null references public.lectodinamicas(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 20 and 5000),
  created_at timestamptz not null default now(),
  unique(dynamic_id,author_id),
  unique(id,dynamic_id)
);
create table if not exists public.votes (
  dynamic_id uuid not null references public.lectodinamicas(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  submission_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(dynamic_id,voter_id),
  foreign key (submission_id,dynamic_id) references public.fragments(id,dynamic_id) on delete cascade
);
create table if not exists public.works (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 110),
  genre text not null check (char_length(genre) between 1 and 40),
  description text not null default '' check (char_length(description) <= 480),
  views integer not null default 0 check (views between 0 and 1000000000),
  url text check (url is null or url ~* '^https?://'),
  created_at timestamptz not null default now()
);
create table if not exists public.readings (
  work_id uuid not null references public.works(id) on delete cascade,
  reader_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(work_id,reader_id)
);
create index if not exists idx_fragments_dynamic on public.fragments(dynamic_id);
create index if not exists idx_votes_submission on public.votes(submission_id);
create index if not exists idx_works_views on public.works(views,created_at);
create index if not exists idx_lectodinamicas_start on public.lectodinamicas(start_date desc);

-- El trigger asigna siempre member al crear cuentas. Nunca lee permisos desde user_metadata.
create or replace function private.create_member_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id,display_name,role)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'),''),split_part(coalesce(new.email,''),'@',1),'Miembro'),65),
    'member'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public, anon, authenticated;
drop trigger if exists ecos_member_after_signup on auth.users;
create trigger ecos_member_after_signup
after insert on auth.users for each row execute function private.create_member_profile();

-- Asegurar un perfil para cualquier cuenta preexistente en ESTE proyecto.
insert into public.profiles(id,display_name,role)
select u.id, left(coalesce(nullif(split_part(coalesce(u.email,''),'@',1),''),'Miembro'),65),'member'
from auth.users u
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.lectodinamicas enable row level security;
alter table public.lectodinamica_images enable row level security;
alter table public.fragments enable row level security;
alter table public.votes enable row level security;
alter table public.works enable row level security;
alter table public.readings enable row level security;

-- Revocar permisos amplios y otorgar exclusivamente operaciones necesarias.
revoke all on public.profiles, public.lectodinamicas, public.lectodinamica_images,
  public.fragments, public.votes, public.works, public.readings from anon, authenticated;
grant usage on schema public to authenticated;
grant select on public.profiles, public.lectodinamicas, public.lectodinamica_images,
  public.fragments, public.votes, public.works, public.readings to authenticated;
-- Importante: role e id NO se pueden editar desde el cliente, incluso con una petición manual.
grant update(display_name,bio,wattpad_url,other_url) on public.profiles to authenticated;
grant insert(created_by,title,theme,prompt,starter,stage,start_date,end_date,id) on public.lectodinamicas to authenticated;
grant update(stage) on public.lectodinamicas to authenticated;
grant insert(dynamic_id,position,label,image_url) on public.lectodinamica_images to authenticated;
grant insert(dynamic_id,author_id,body) on public.fragments to authenticated;
grant update(body) on public.fragments to authenticated;
grant insert(dynamic_id,voter_id,submission_id) on public.votes to authenticated;
grant update(submission_id) on public.votes to authenticated;
grant delete on public.votes to authenticated;
grant insert(author_id,title,genre,description,views,url) on public.works to authenticated;
grant update(title,genre,description,views,url) on public.works to authenticated;
grant insert(work_id,reader_id) on public.readings to authenticated;
grant delete on public.readings to authenticated;

create policy "Profiles visible to signed-in members" on public.profiles
for select to authenticated using (true);
create policy "Edit own public profile" on public.profiles
for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "Read lectodinamicas" on public.lectodinamicas
for select to authenticated using (true);
create policy "Staff create lectodinamicas" on public.lectodinamicas
for insert to authenticated with check (
  created_by = (select auth.uid()) and
  exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('admin','moderator'))
);
create policy "Staff close and open lectodinamicas" on public.lectodinamicas
for update to authenticated using (
  exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('admin','moderator'))
) with check (
  exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('admin','moderator'))
);

create policy "Read reference images" on public.lectodinamica_images
for select to authenticated using (true);
create policy "Staff add reference images" on public.lectodinamica_images
for insert to authenticated with check (
  exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('admin','moderator'))
  and exists(select 1 from public.lectodinamicas d where d.id = dynamic_id)
);

create policy "Read entries" on public.fragments
for select to authenticated using (true);
create policy "Authors post in open lectodinamicas" on public.fragments
for insert to authenticated with check (
  author_id = (select auth.uid()) and
  exists(select 1 from public.lectodinamicas d where d.id = dynamic_id and d.stage = 'open')
);
create policy "Authors revise entries only while open" on public.fragments
for update to authenticated
using (
  author_id = (select auth.uid())
  and exists(select 1 from public.lectodinamicas d where d.id = dynamic_id and d.stage = 'open')
) with check (
  author_id = (select auth.uid())
  and exists(select 1 from public.lectodinamicas d where d.id = dynamic_id and d.stage = 'open')
);

create policy "Read votes" on public.votes
for select to authenticated using (true);
create policy "Vote once, never for yourself" on public.votes
for insert to authenticated with check (
  voter_id = (select auth.uid()) and
  exists (
    select 1 from public.fragments f
    join public.lectodinamicas d on d.id = f.dynamic_id
    where f.id = submission_id and f.dynamic_id = dynamic_id
      and f.author_id <> (select auth.uid()) and d.stage = 'open'
  )
);
create policy "Change vote only while open" on public.votes
for update to authenticated
using (
  voter_id = (select auth.uid()) and
  exists(select 1 from public.lectodinamicas d where d.id = dynamic_id and d.stage = 'open')
) with check (
  voter_id = (select auth.uid()) and
  exists (
    select 1 from public.fragments f
    join public.lectodinamicas d on d.id = f.dynamic_id
    where f.id = submission_id and f.dynamic_id = dynamic_id
      and f.author_id <> (select auth.uid()) and d.stage = 'open'
  )
);
create policy "Withdraw vote only while open" on public.votes
for delete to authenticated using (
  voter_id = (select auth.uid()) and
  exists(select 1 from public.lectodinamicas d where d.id = dynamic_id and d.stage = 'open')
);

create policy "Read promoted works" on public.works
for select to authenticated using (true);
create policy "Promote own works" on public.works
for insert to authenticated with check (author_id = (select auth.uid()));
create policy "Edit own works" on public.works
for update to authenticated using (author_id = (select auth.uid()))
with check (author_id = (select auth.uid()));

create policy "Read own reading status" on public.readings
for select to authenticated using (reader_id = (select auth.uid()));
create policy "Mark own reading" on public.readings
for insert to authenticated with check (reader_id = (select auth.uid()));
create policy "Unmark own reading" on public.readings
for delete to authenticated using (reader_id = (select auth.uid()));

-- Imágenes de retos en bucket de lectura pública.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('lectodinamicas','lectodinamicas',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "Publicly serve lectodinamica pictures" on storage.objects
for select to public using (bucket_id = 'lectodinamicas');
create policy "Only staff upload lectodinamica pictures" on storage.objects
for insert to authenticated with check (
  bucket_id = 'lectodinamicas'
  and exists(select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin','moderator'))
);
commit;

-- Solo después de registrar tu propia cuenta, ejecutar por separado en el SQL Editor:
-- update public.profiles set role='admin'
-- where id=(select id from auth.users where email='TU_CORREO@DOMINIO.COM');
-- Nunca colocar claves privadas, contraseñas o tokens en GitHub.
