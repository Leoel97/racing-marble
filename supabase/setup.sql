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

-- 8) L'app aggiunge le vittorie solo al profilo di chi e' collegato.
create or replace function public.add_wins(amount integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  total integer;
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  if amount < 1 or amount > 50 then
    raise exception 'invalid amount';
  end if;
  update public.profiles
     set wins = wins + amount
   where id = (select auth.uid())
  returning wins into total;
  return coalesce(total, 0);
end;
$$;

revoke all on function public.add_wins(integer) from public, anon;
grant execute on function public.add_wins(integer) to authenticated;
