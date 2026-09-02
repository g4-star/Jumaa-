create table if not exists public.push_tokens (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    token text not null unique,

    platform text not null default 'android'
        check (platform in ('android', 'ios', 'web')),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_id_idx
    on public.push_tokens(user_id);

alter table public.push_tokens enable row level security;

drop policy if exists "Users can view their own push tokens"
    on public.push_tokens;

create policy "Users can view their own push tokens"
on public.push_tokens
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can register their own push tokens"
    on public.push_tokens;

create policy "Users can register their own push tokens"
on public.push_tokens
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can update their own push tokens"
    on public.push_tokens;

create policy "Users can update their own push tokens"
on public.push_tokens
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete their own push tokens"
    on public.push_tokens;

create policy "Users can delete their own push tokens"
on public.push_tokens
for delete
to authenticated
using (user_id = auth.uid());

create or replace function public.update_push_token_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists push_tokens_updated_at
    on public.push_tokens;

create trigger push_tokens_updated_at
before update on public.push_tokens
for each row
execute function public.update_push_token_timestamp();
