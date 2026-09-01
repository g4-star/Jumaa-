-- ============================================================
-- JUMAA FINAL MESSAGING RLS FIX
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_access_property_for_messaging(
  p_property_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    -- TENANT
    EXISTS (
      SELECT 1
      FROM public.tenants t
      WHERE t.auth_user_id = p_user_id
        AND t.property_id = p_property_id
        AND lower(trim(coalesce(t.account_status, ''))) = 'active'
    )

    OR

    -- LANDLORD
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = p_property_id
        AND p.landlord_id = p_user_id
    )

    OR

    -- PROPERTY OWNER
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = p_property_id
        AND p.owner_id = p_user_id
    )

    OR

    -- JUMAA OWNER
    EXISTS (
      SELECT 1
      FROM public.profiles pr
      WHERE pr.id = p_user_id
        AND pr.role = 'jumaa_owner'
    );
$$;

ALTER FUNCTION public.can_access_property_for_messaging(uuid, uuid)
OWNER TO postgres;

GRANT EXECUTE
ON FUNCTION public.can_access_property_for_messaging(uuid, uuid)
TO authenticated;

-- Recreate the conversation INSERT policy cleanly.
DROP POLICY IF EXISTS "jumaa_users_create_conversations"
ON public.conversations;

CREATE POLICY "jumaa_users_create_conversations"
ON public.conversations
FOR INSERT
TO authenticated
WITH CHECK (
  public.can_access_property_for_messaging(
    property_id,
    auth.uid()
  )
);

-- Allow a user to add themselves as a participant.
DROP POLICY IF EXISTS "jumaa_users_add_conversation_participants"
ON public.conversation_participants;

CREATE POLICY "jumaa_users_add_conversation_participants"
ON public.conversation_participants
FOR INSERT
TO authenticated
WITH CHECK (
  profile_id = auth.uid()
  OR public.is_conversation_participant(
    conversation_id,
    auth.uid()
  )
);
