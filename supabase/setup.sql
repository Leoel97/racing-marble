-- Racing Marble: nickname univoci.
-- Da eseguire una volta sola nel SQL Editor di Supabase. Si puo' rieseguire senza danni.

-- 1) Un profilo per ogni account, con il nickname.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null check (char_length(nickname) between 3 and 16),
  created_at timestamptz not null default now()
);

-- 2) Nickname unico senza distinguere maiuscole e minuscole ("Lello" = "lello").
create unique index if not exists profiles_nickname_unique
  on public.profiles (lower(nickname));

-- 3) Nessuno legge la tabella dall'app, tranne il proprio profilo.
alter table public.profiles enable row level security;
drop policy if exists "Ognuno legge il proprio profilo" on public.profiles;
create policy "Ognuno legge il proprio profilo"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

-- 4) Alla registrazione il profilo viene creato in automatico.
--    Se il nickname e' gia' preso, la registrazione viene rifiutata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nickname)
  values (new.id, btrim(new.raw_user_meta_data ->> 'nickname'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) Domanda che l'app fa prima di registrare: "questo nickname e' libero?"
create or replace function public.nickname_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles where lower(nickname) = lower(btrim(candidate))
  );
$$;

revoke all on function public.nickname_available(text) from public;
grant execute on function public.nickname_available(text) to anon, authenticated;

-- 6) Profili per gli account creati prima di questo script.
insert into public.profiles (id, nickname)
select id, btrim(raw_user_meta_data ->> 'nickname')
from auth.users
where char_length(coalesce(btrim(raw_user_meta_data ->> 'nickname'), '')) between 3 and 16
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Vittorie (aggiunta del passo "personalizzazione"). Rieseguibile senza danni.
-- ---------------------------------------------------------------------------

-- 7) Vittorie totali (primi posti) salvate sul profilo.
alter table public.profiles
  add column if not exists wins integer not null default 0;

-- 8) Gare: il server segna quando una gara inizia. Una vittoria viene accettata solo
--    se quella gara esiste, e' di chi la dichiara, non e' gia' stata chiusa ed e' durata
--    un tempo credibile. L'app non puo' piu' "aggiungere vittorie" a piacere.
create table if not exists public.races (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  won boolean
);
create index if not exists races_user_idx on public.races (user_id, started_at);
alter table public.races enable row level security;   -- nessuna policy: dall'app non si legge ne' si scrive

create or replace function public.start_race()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  race_id uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  delete from public.races where user_id = uid and started_at < now() - interval '1 day';
  insert into public.races (user_id) values (uid) returning id into race_id;
  return race_id;
end;
$$;

create or replace function public.finish_race(race uuid, won boolean)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  started timestamptz;
  elapsed interval;
  counted boolean := coalesce(won, false);
  total integer;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  select r.started_at into started
    from public.races r
   where r.id = race and r.user_id = uid and r.finished_at is null
   for update;
  if started is null then
    raise exception 'race not found';
  end if;
  elapsed := now() - started;
  -- troppo breve per essere una gara vera, o lasciata aperta troppo a lungo: non vale
  if elapsed < interval '18 seconds' or elapsed > interval '15 minutes' then
    counted := false;
  end if;
  update public.races r set finished_at = now(), won = counted where r.id = race;
  if counted then
    update public.profiles set wins = wins + 1 where id = uid;
  end if;
  select p.wins into total from public.profiles p where p.id = uid;
  return coalesce(total, 0);
end;
$$;

revoke all on function public.start_race() from public, anon;
revoke all on function public.finish_race(uuid, boolean) from public, anon;
grant execute on function public.start_race() to authenticated;
grant execute on function public.finish_race(uuid, boolean) to authenticated;

-- 9) La vecchia funzione che lasciava decidere all'app viene eliminata.
drop function if exists public.add_wins(integer);
