create table if not exists public.password_reset_codes (
  id uuid primary key default gen_random_uuid(),

  email text not null,

  code_hash text not null,

  expires_at timestamptz not null,

  used boolean not null default false,

  attempts integer not null default 0,

  created_at timestamptz not null default now()
);

create index if not exists password_reset_codes_email_idx
  on public.password_reset_codes (email);

create index if not exists password_reset_codes_code_hash_idx
  on public.password_reset_codes (code_hash);

create index if not exists password_reset_codes_expires_at_idx
  on public.password_reset_codes (expires_at);

alter table public.password_reset_codes enable row level security;

revoke all on public.password_reset_codes from anon;
revoke all on public.password_reset_codes from authenticated;
