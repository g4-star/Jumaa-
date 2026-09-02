-- ============================================================
-- JUMAA: ATOMIC BOOKING APPROVAL + EXACT UNIT ASSIGNMENT
--
-- Pending booking:
--   - selected unit remains vacant
--
-- Approval:
--   - locks booking
--   - locks exact selected unit
--   - verifies landlord ownership
--   - verifies unit is still vacant
--   - verifies no tenant already occupies it
--   - assigns tenant to the exact selected unit
--   - marks unit occupied
--   - marks booking approved
--
-- If the unit was already taken, the whole transaction fails.
-- ============================================================

create or replace function public.approve_booking_request(
    p_booking_id uuid,
    p_tenant_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_booking public.booking_requests%rowtype;
    v_unit public.units%rowtype;
    v_tenant public.tenants%rowtype;
    v_existing_tenant public.tenants%rowtype;
begin
    if auth.uid() is null then
        raise exception 'Authentication is required';
    end if;

    if p_booking_id is null then
        raise exception 'Booking request ID is required';
    end if;

    if p_tenant_id is null then
        raise exception 'Tenant ID is required';
    end if;

    -- --------------------------------------------------------
    -- Lock the booking request first.
    -- --------------------------------------------------------
    select *
    into v_booking
    from public.booking_requests
    where id = p_booking_id
    for update;

    if not found then
        raise exception 'Booking request not found';
    end if;

    -- --------------------------------------------------------
    -- Only the landlord assigned to this property may approve.
    -- --------------------------------------------------------
    if not exists (
        select 1
        from public.properties p
        where p.id = v_booking.property_id
          and p.landlord_id = auth.uid()
    ) then
        raise exception 'You are not authorized to approve this booking';
    end if;

    -- --------------------------------------------------------
    -- Only pending requests can be approved.
    -- --------------------------------------------------------
    if v_booking.status <> 'pending' then
        raise exception
            'This booking is no longer pending (current status: %)',
            v_booking.status;
    end if;

    -- --------------------------------------------------------
    -- Lock the EXACT unit selected by the applicant.
    -- --------------------------------------------------------
    select *
    into v_unit
    from public.units
    where id = v_booking.unit_id
      and property_id = v_booking.property_id
    for update;

    if not found then
        raise exception
            'The selected unit no longer belongs to this property';
    end if;

    -- --------------------------------------------------------
    -- The selected unit MUST still be vacant.
    -- --------------------------------------------------------
    if lower(coalesce(v_unit.status::text, '')) <> 'vacant' then
        raise exception
            'The selected unit is no longer available. It is currently %.',
            coalesce(v_unit.status::text, 'unknown');
    end if;

    -- --------------------------------------------------------
    -- Verify that the tenant record belongs to this booking.
    -- --------------------------------------------------------
    select *
    into v_tenant
    from public.tenants
    where id = p_tenant_id
      and booking_request_id = p_booking_id
    for update;

    if not found then
        raise exception
            'The tenant record does not belong to this booking request';
    end if;

    -- --------------------------------------------------------
    -- Prevent a different tenant from occupying this unit.
    -- --------------------------------------------------------
    select *
    into v_existing_tenant
    from public.tenants
    where unit_id = v_booking.unit_id
      and id <> p_tenant_id
      and account_status = 'active'
    limit 1
    for update;

    if found then
        raise exception
            'This unit is already assigned to another tenant';
    end if;

    -- --------------------------------------------------------
    -- Make absolutely sure the tenant gets the EXACT unit
    -- selected in the booking request.
    -- --------------------------------------------------------
    update public.tenants
    set
        property_id = v_booking.property_id,
        unit_id = v_booking.unit_id,
        account_status = 'active',
        updated_at = now()
    where id = p_tenant_id;

    -- --------------------------------------------------------
    -- Mark the EXACT selected unit occupied.
    -- --------------------------------------------------------
    update public.units
    set status = 'occupied'
    where id = v_booking.unit_id;

    -- --------------------------------------------------------
    -- Finally approve the booking.
    -- --------------------------------------------------------
    update public.booking_requests
    set
        status = 'approved',
        updated_at = now()
    where id = p_booking_id;

    return jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'tenant_id', p_tenant_id,
        'property_id', v_booking.property_id,
        'unit_id', v_booking.unit_id,
        'unit_status', 'occupied',
        'booking_status', 'approved'
    );

exception
    when others then
        raise exception 'Booking approval failed: %', SQLERRM;
end;
$$;

revoke all
on function public.approve_booking_request(uuid, uuid)
from public;

grant execute
on function public.approve_booking_request(uuid, uuid)
to authenticated;
