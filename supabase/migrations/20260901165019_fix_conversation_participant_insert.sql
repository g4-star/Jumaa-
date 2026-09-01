-- ============================================================
-- JUMAA: FIX CONVERSATION PARTICIPANT INSERT
-- ============================================================

-- SECURITY DEFINER allows the authorization check to inspect
-- conversation_participants without being blocked by its RLS.

CREATE OR REPLACE FUNCTION public.is_conversation_participant(
  p_conversation_id uuid,
  p_profile_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
      AND cp.profile_id = p_profile_id
  );
$$;

ALTER FUNCTION public.is_conversation_participant(uuid, uuid)
  OWNER TO postgres;

REVOKE ALL ON FUNCTION public.is_conversation_participant(uuid, uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_conversation_participant(uuid, uuid)
  TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_conversation_participant(uuid, uuid)
  TO service_role;


-- Replace the participant INSERT policy.
DROP POLICY IF EXISTS
  "jumaa_users_add_conversation_participants"
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

