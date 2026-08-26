-- ============================================================
-- JUMAA: BOOKING REQUESTS
-- ============================================================

create table if not exists public.booking_requests (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references public.properties(id)
        on delete cascade,

    unit_id uuid not null
        references public.units(id)
        on delete cascade,

    applicant_name text not null,
    applicant_email text not null,
    applicant_phone text not null,

    national_id text,
    occupation text,
    employer text,

    preferred_move_in_date date,

    additional_notes text default '',

    status text not null default 'pending'
        check (
            status in (
                'pending',
                'approved',
                'rejected',
                'cancelled'
            )
        ),

    landlord_notes text default '',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_booking_requests_property
    on public.booking_requests(property_id);

create index if not exists idx_booking_requests_unit
    on public.booking_requests(unit_id);

create index if not exists idx_booking_requests_status
    on public.booking_requests(status);

-- Automatically maintain updated_at.
create or replace function public.set_booking_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists booking_requests_updated_at
on public.booking_requests;

create trigger booking_requests_updated_at
before update on public.booking_requests
for each row
execute function public.set_booking_requests_updated_at();
