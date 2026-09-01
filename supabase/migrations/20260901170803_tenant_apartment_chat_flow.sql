-- ============================================================
-- JUMAA: TENANT APARTMENT CHAT FLOW
-- ============================================================
--
-- Creates a secure RPC for creating/finding a conversation
-- between the logged-in user and another member of the same
-- property.
--
-- The Flutter client never gets permission to bypass RLS.
-- SECURITY DEFINER performs the controlled database operation.
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
  v_current_allowed boolean := false;
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

  -- ----------------------------------------------------------
  -- Verify current user belongs to this property.
  -- ----------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = v_current_user
      AND t.property_id = p_property_id
      AND t.account_status = 'active'
  )
  OR EXISTS (
    SELECT 1
    FROM public.landlords l
    JOIN public.properties p
      ON p.landlord_id = l.id
    WHERE p.id = p_property_id
      AND l.auth_user_id = v_current_user
  )
  INTO v_current_allowed;

  IF NOT v_current_allowed THEN
    RAISE EXCEPTION 'You do not have access to this property';
  END IF;

  -- ----------------------------------------------------------
  -- Verify receiver is either:
  --   1. The landlord of this property, OR
  --   2. An active tenant of this property.
  -- ----------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.landlords l
    JOIN public.properties p
      ON p.landlord_id = l.id
    WHERE p.id = p_property_id
      AND l.auth_user_id = p_receiver_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = p_receiver_id
      AND t.property_id = p_property_id
      AND t.account_status = 'active'
  )
  INTO v_receiver_allowed;

  IF NOT v_receiver_allowed THEN
    RAISE EXCEPTION 'Receiver is not a member of this property';
  END IF;

  -- ----------------------------------------------------------
  -- Find an existing conversation containing both users.
  -- ----------------------------------------------------------

  SELECT c.id
  INTO v_conversation_id
  FROM public.conversations c
  WHERE c.property_id = p_property_id
    AND EXISTS (
      SELECT 1
      FROM public.conversation_participants cp1
      WHERE cp1.conversation_id = c.id
        AND cp1.profile_id = v_current_user
    )
    AND EXISTS (
      SELECT 1
      FROM public.conversation_participants cp2
      WHERE cp2.conversation_id = c.id
        AND cp2.profile_id = p_receiver_id
    )
  LIMIT 1;

  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;

  -- ----------------------------------------------------------
  -- Create the conversation.
  -- ----------------------------------------------------------

  INSERT INTO public.conversations (
    property_id
  )
  VALUES (
    p_property_id
  )
  RETURNING id INTO v_conversation_id;

  -- ----------------------------------------------------------
  -- Add both participants.
  -- SECURITY DEFINER allows this controlled operation.
  -- ----------------------------------------------------------

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

REVOKE ALL
ON FUNCTION public.get_or_create_apartment_conversation(uuid, uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.get_or_create_apartment_conversation(uuid, uuid)
TO authenticated;
