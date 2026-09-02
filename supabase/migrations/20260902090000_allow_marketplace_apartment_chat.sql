-- ============================================================
-- JUMAA: ALLOW AUTHENTICATED MARKETPLACE USERS TO CHAT
-- WITH THE LANDLORD OF A SPECIFIC APARTMENT
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_or_create_apartment_conversation(
    p_property_id uuid,
    p_receiver_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_user uuid;
    v_conversation_id uuid;
    v_receiver_allowed boolean := false;
BEGIN
    v_current_user := auth.uid();

    IF v_current_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF p_property_id IS NULL OR p_receiver_id IS NULL THEN
        RAISE EXCEPTION 'Property and receiver are required';
    END IF;

    IF v_current_user = p_receiver_id THEN
        RAISE EXCEPTION 'You cannot create a conversation with yourself';
    END IF;

    -- The receiver MUST be the landlord assigned to this property.
    SELECT EXISTS (
        SELECT 1
        FROM public.properties p
        WHERE p.id = p_property_id
          AND p.landlord_id = p_receiver_id
    )
    INTO v_receiver_allowed;

    IF NOT v_receiver_allowed THEN
        RAISE EXCEPTION 'Receiver is not the landlord assigned to this property';
    END IF;

    -- Reuse an existing conversation between these two users
    -- for this property.
    SELECT c.id
    INTO v_conversation_id
    FROM public.conversations c
    WHERE c.property_id = p_property_id
      AND EXISTS (
          SELECT 1
          FROM public.conversation_participants cp
          WHERE cp.conversation_id = c.id
            AND cp.profile_id = v_current_user
      )
      AND EXISTS (
          SELECT 1
          FROM public.conversation_participants cp
          WHERE cp.conversation_id = c.id
            AND cp.profile_id = p_receiver_id
      )
    LIMIT 1;

    IF v_conversation_id IS NOT NULL THEN
        RETURN v_conversation_id;
    END IF;

    INSERT INTO public.conversations (property_id)
    VALUES (p_property_id)
    RETURNING id INTO v_conversation_id;

    INSERT INTO public.conversation_participants (
        conversation_id,
        profile_id
    )
    VALUES
        (v_conversation_id, v_current_user),
        (v_conversation_id, p_receiver_id);

    RETURN v_conversation_id;
END;
$$;

ALTER FUNCTION public.get_or_create_apartment_conversation(uuid, uuid)
OWNER TO postgres;

REVOKE ALL
ON FUNCTION public.get_or_create_apartment_conversation(uuid, uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.get_or_create_apartment_conversation(uuid, uuid)
TO authenticated;
