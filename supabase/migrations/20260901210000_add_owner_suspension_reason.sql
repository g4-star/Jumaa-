alter table public.profiles
add column if not exists suspension_reason text;

alter table public.profiles
add column if not exists suspended_at timestamptz;

