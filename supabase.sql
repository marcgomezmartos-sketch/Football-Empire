-- Ejecutar en Supabase SQL Editor
create table if not exists public.clubs (
 user_id uuid primary key references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 3 and 32),
 money integer not null default 450 check (money >= 0),
 strength integer not null default 10 check (strength >= 1),
 matches integer not null default 0 check (matches >= 0),
 created_at timestamptz not null default now()
);
alter table public.clubs enable row level security;
create policy "Read own club" on public.clubs for select to authenticated using ((select auth.uid()) = user_id);
create policy "Create own club" on public.clubs for insert to authenticated with check ((select auth.uid()) = user_id and money=450 and strength=10 and matches=0);
-- The match result and money are updated server-side, not trusted from the browser.
create or replace function public.play_match() returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.clubs%rowtype; won boolean; prize integer;
begin
 select * into c from public.clubs where user_id=auth.uid() for update;
 if not found then raise exception 'No tienes club'; end if;
 won := random() < least(0.65, 0.28 + c.strength * 0.003);
 prize := case when won then 55 else 10 end;
 update public.clubs set money=money+prize,matches=matches+1 where user_id=auth.uid();
 return jsonb_build_object('won',won,'prize',prize,'message',case when won then '¡Victoria! +55 €' else 'Derrota. +10 €' end);
end;$$;
revoke all on function public.play_match() from public;
grant execute on function public.play_match() to authenticated;
