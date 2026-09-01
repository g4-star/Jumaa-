-- ============================================================
-- JUMAA: FIX APARTMENT CHAT RPC
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
    v_current_allowed boolean := false;
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

    -- Verify current user can access the property.
    v_current_allowed :=
        public.can_access_property_for_messaging(
            p_property_id,
            v_current_user
        );

    IF NOT v_current_allowed THEN
        RAISE EXCEPTION 'You do not have access to this property';
    END IF;

    -- Verify receiver belongs to this property.
    -- Landlord identity:
    -- properties.landlord_id = landlords.id = auth.users.id
    SELECT
        EXISTS (
            SELECT 1
            FROM public.properties p
            WHERE p.id = p_property_id
              AND p.landlord_id = p_receiver_id
        )
        OR
        EXISTS (
            SELECT 1
            FROM public.tenants t
            WHERE t.auth_user_id = p_receiver_id
              AND t.property_id = p_property_id
              AND lower(trim(coalesce(t.account_status, ''))) = 'active'
        )
    INTO v_receiver_allowed;

    IF NOT v_receiver_allowed THEN
        RAISE EXCEPTION 'Receiver is not a member of this property';
    END IF;

    -- Find existing conversation between both users.
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

    -- Create conversation.
    INSERT INTO public.conversations (
        property_id
    )
    VALUES (
        p_property_id
    )
    RETURNING id INTO v_conversation_id;

    -- Add both participants.
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
