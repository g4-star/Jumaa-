-- ============================================================
-- JUMAA: FIX TENANT CONVERSATION CREATION
-- ============================================================

-- Replace the messaging authorization helper with a SECURITY
-- DEFINER function so it can safely inspect tenant/property
-- relationships without being blocked by RLS.

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
  SELECT EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = p_user_id
      AND t.property_id = p_property_id
      AND t.account_status = 'active'
  )
  OR EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = p_property_id
      AND p.landlord_id = p_user_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = p_property_id
      AND p.owner_id = p_user_id
  );
$$;

-- Make sure authenticated users can execute the helper.
GRANT EXECUTE
ON FUNCTION public.can_access_property_for_messaging(uuid, uuid)
TO authenticated;

-- Remove the old conversation INSERT policy.
DROP POLICY IF EXISTS "jumaa_users_create_conversations"
ON public.conversations;

-- Recreate it using the helper.
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
