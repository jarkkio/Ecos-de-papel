-- 03_usuario_password.sql · Ecos de Papel
-- Migración aplicada el 13 de octubre de 2026 a Supabase Ecos de Papel.
-- No volver a ejecutar en el proyecto conectado ni aplicar en UMBRA.
alter table public.profiles
  add column if not exists username text unique
  check (username is null or username ~ '^[a-z0-9_]{3,24}$');

create or replace function private.create_member_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id,display_name,role,username)
  values(
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'),''),split_part(coalesce(new.email,''),'@',1),'Miembro'),65),
    'member',
    case when coalesce(new.email,'') ~ '^[a-z0-9_]{3,24}@login[.]ecos-de-papel[.]invalid$'
      then split_part(new.email,'@',1)
      else null end
  ) on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public, anon, authenticated;

create table if not exists private.ecos_signup_attempts (
  ip_hash text primary key check (ip_hash ~ '^[0-9a-f]{64}$'),
  started_at timestamptz not null default now(),
  attempts smallint not null default 1 check (attempts between 1 and 32767)
);
revoke all on private.ecos_signup_attempts from public,anon,authenticated;

create or replace function public.reserve_ecos_signup_slot(p_ip_hash text)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare attempts_now integer;
begin
  if p_ip_hash !~ '^[0-9a-f]{64}$' then return false; end if;
  insert into private.ecos_signup_attempts(ip_hash,started_at,attempts)
  values(p_ip_hash,now(),1)
  on conflict (ip_hash) do update set
    started_at=case when private.ecos_signup_attempts.started_at < now()-interval '1 hour'
      then now() else private.ecos_signup_attempts.started_at end,
    attempts=case when private.ecos_signup_attempts.started_at < now()-interval '1 hour'
      then 1 else least(private.ecos_signup_attempts.attempts+1,32767) end
  returning attempts into attempts_now;
  return attempts_now <= 5;
end;
$$;
revoke all on function public.reserve_ecos_signup_slot(text) from public,anon,authenticated;
grant execute on function public.reserve_ecos_signup_slot(text) to service_role;
