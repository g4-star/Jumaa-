-- ============================================================
-- JUMAA: SECURE BOOKING REQUEST CREATION
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_booking_request(
    p_property_id uuid,
    p_unit_id uuid,
    p_applicant_name text,
    p_applicant_email text,
    p_applicant_phone text,
    p_additional_notes text DEFAULT ''
)
RETURNS public.booking_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.booking_requests;
BEGIN
    -- Basic validation
    IF p_property_id IS NULL THEN
        RAISE EXCEPTION 'Property information is required';
    END IF;

    IF p_unit_id IS NULL THEN
        RAISE EXCEPTION 'Unit information is required';
    END IF;

    IF trim(coalesce(p_applicant_name, '')) = '' THEN
        RAISE EXCEPTION 'Applicant name is required';
    END IF;

    IF trim(coalesce(p_applicant_email, '')) = '' THEN
        RAISE EXCEPTION 'Applicant email is required';
    END IF;

    IF trim(coalesce(p_applicant_phone, '')) = '' THEN
        RAISE EXCEPTION 'Applicant phone is required';
    END IF;

    -- Verify that the unit actually belongs to the selected property.
    IF NOT EXISTS (
        SELECT 1
        FROM public.units u
        WHERE u.id = p_unit_id
          AND u.property_id = p_property_id
    ) THEN
        RAISE EXCEPTION 'The selected unit does not belong to this property';
    END IF;

    -- Create the booking request.
    INSERT INTO public.booking_requests (
        property_id,
        unit_id,
        applicant_name,
        applicant_email,
        applicant_phone,
        additional_notes,
        status
    )
    VALUES (
        p_property_id,
        p_unit_id,
        trim(p_applicant_name),
        lower(trim(p_applicant_email)),
        trim(p_applicant_phone),
        trim(coalesce(p_additional_notes, '')),
        'pending'
    )
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$;

ALTER FUNCTION public.create_booking_request(
    uuid,
    uuid,
    text,
    text,
    text,
    text
) OWNER TO postgres;

REVOKE ALL
ON FUNCTION public.create_booking_request(
    uuid,
    uuid,
    text,
    text,
    text,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.create_booking_request(
    uuid,
    uuid,
    text,
    text,
    text,
    text
)
TO anon, authenticated;
