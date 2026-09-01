-- Helper used only by conversation RLS checks.
-- SECURITY DEFINER allows the authorization check to inspect
-- tenants/properties without being blocked by their RLS policies.

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
    WHERE t.property_id = p_property_id
      AND t.auth_user_id = p_user_id
      AND t.account_status = 'active'
  )
  OR EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = p_property_id
      AND (
        p.owner_id = p_user_id
        OR p.landlord_id = p_user_id
      )
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_property_for_messaging(uuid, uuid)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.can_access_property_for_messaging(uuid, uuid)
TO authenticated;


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
