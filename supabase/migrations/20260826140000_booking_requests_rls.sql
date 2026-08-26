-- ============================================================
-- JUMAA: BOOKING REQUESTS RLS
--
-- Public users may submit booking requests.
-- Landlords may view/update requests belonging to their
-- assigned properties.
-- ============================================================

-- Enable Row Level Security.
alter table public.booking_requests enable row level security;


-- ============================================================
-- LANDLORD: VIEW BOOKING REQUESTS
--
-- A landlord can only see booking requests whose property
-- belongs to that authenticated landlord.
-- ============================================================

drop policy if exists "landlords_view_own_booking_requests"
on public.booking_requests;

create policy "landlords_view_own_booking_requests"
on public.booking_requests
for select
to authenticated
using (
    exists (
        select 1
        from public.properties p
        where p.id = booking_requests.property_id
          and p.landlord_id = auth.uid()
    )
);


-- ============================================================
-- LANDLORD: UPDATE BOOKING REQUESTS
--
-- Required for approving/rejecting/cancelling requests and
-- updating landlord notes.
-- ============================================================

drop policy if exists "landlords_update_own_booking_requests"
on public.booking_requests;

create policy "landlords_update_own_booking_requests"
on public.booking_requests
for update
to authenticated
using (
    exists (
        select 1
        from public.properties p
        where p.id = booking_requests.property_id
          and p.landlord_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.properties p
        where p.id = booking_requests.property_id
          and p.landlord_id = auth.uid()
    )
);


-- ============================================================
-- PUBLIC: SUBMIT BOOKING REQUESTS
--
-- Keep public booking submission working.
-- This allows unauthenticated and authenticated public users
-- to create a booking request.
-- ============================================================

drop policy if exists "public_create_booking_requests"
on public.booking_requests;

create policy "public_create_booking_requests"
on public.booking_requests
for insert
to anon, authenticated
with check (
    exists (
        select 1
        from public.properties p
        where p.id = booking_requests.property_id
    )
    and
    exists (
        select 1
        from public.units u
        where u.id = booking_requests.unit_id
          and u.property_id = booking_requests.property_id
    )
);
