-- ============================================================
-- JUMAA USER ACCOUNT STATUS
-- ============================================================

alter table public.profiles
add column if not exists account_status text
default 'active'
check (account_status in ('active', 'suspended'));

update public.profiles
set account_status = 'active'
where account_status is null;

alter table public.profiles
alter column account_status set default 'active';

alter table public.profiles
alter column account_status set not null;
