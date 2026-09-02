-- ============================================================
-- JUMAA: SECURE PUBLIC BOOKING VALIDATION
-- ============================================================

create or replace function public.can_create_booking_request(
    p_property_id uuid,
    p_unit_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (
        select 1
        from public.units u
        join public.properties p
          on p.id = u.property_id
        where u.id = p_unit_id
          and u.property_id = p_property_id
    );
$$;

alter function public.can_create_booking_request(uuid, uuid)
owner to postgres;

revoke all
on function public.can_create_booking_request(uuid, uuid)
from public;

grant execute
on function public.can_create_booking_request(uuid, uuid)
to anon, authenticated;


drop policy if exists "public_create_booking_requests"
on public.booking_requests;

create policy "public_create_booking_requests"
on public.booking_requests
for insert
to anon, authenticated
with check (
    public.can_create_booking_request(
        property_id,
        unit_id
    )
);
