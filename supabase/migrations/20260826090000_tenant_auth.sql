-- ============================================================
-- TENANT AUTHENTICATION
-- Link each tenant application record to its Supabase Auth user.
-- ============================================================

alter table public.tenants
add column if not exists auth_user_id uuid unique;

create index if not exists idx_tenants_auth_user_id
    on public.tenants(auth_user_id);
