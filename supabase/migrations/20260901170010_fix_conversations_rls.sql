-- JUMAA: Fix conversation creation RLS for tenants, landlords,
-- property owners and JUMAA owner.

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
