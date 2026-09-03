-- ============================================================
-- JUMAA OWNER REQUESTS
-- Apartment owners can send requests to the JUMAA platform owner.
-- ============================================================

create table if not exists public.owner_requests (
    id uuid primary key default gen_random_uuid(),

    owner_id uuid not null
        references public.profiles(id)
        on delete cascade,

    request_type text not null default 'general',

    subject text not null,

    message text not null,

    status text not null default 'pending'
        check (status in ('pending', 'accepted', 'rejected')),

    rejection_reason text,

    requested_until date,

    reviewed_at timestamptz,

    reviewed_by uuid
        references public.profiles(id)
        on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================

create index if not exists idx_owner_requests_owner_id
on public.owner_requests(owner_id);

create index if not exists idx_owner_requests_status
on public.owner_requests(status);

create index if not exists idx_owner_requests_created_at
on public.owner_requests(created_at desc);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

create or replace function public.update_owner_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists owner_requests_updated_at
on public.owner_requests;

create trigger owner_requests_updated_at
before update on public.owner_requests
for each row
execute function public.update_owner_requests_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.owner_requests enable row level security;

-- ============================================================
-- APARTMENT OWNER:
-- Can create their own request.
-- Can view their own requests.
-- ============================================================

drop policy if exists "Owners can create their own requests"
on public.owner_requests;

create policy "Owners can create their own requests"
on public.owner_requests
for insert
to authenticated
with check (
    owner_id = auth.uid()
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'owner'
    )
);

drop policy if exists "Owners can view their own requests"
on public.owner_requests;

create policy "Owners can view their own requests"
on public.owner_requests
for select
to authenticated
using (
    owner_id = auth.uid()
);

-- ============================================================
-- JUMAA PLATFORM OWNER:
-- Can view all requests.
-- Can update requests.
-- ============================================================

drop policy if exists "JUMAA owners can view all requests"
on public.owner_requests;

create policy "JUMAA owners can view all requests"
on public.owner_requests
for select
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'jumaa_owner'
    )
);

drop policy if exists "JUMAA owners can update requests"
on public.owner_requests;

create policy "JUMAA owners can update requests"
on public.owner_requests
for update
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'jumaa_owner'
    )
)
with check (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'jumaa_owner'
    )
);

-- ============================================================
-- NO DELETE POLICY
-- Requests should remain as a record.
-- ============================================================

