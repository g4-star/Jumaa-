DROP POLICY IF EXISTS "jumaa_users_create_conversations"
ON public.conversations;

CREATE POLICY "jumaa_users_create_conversations"
ON public.conversations
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = auth.uid()
      AND t.property_id = conversations.property_id
      AND t.account_status = 'active'
  )
  OR
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = conversations.property_id
      AND (
        p.owner_id = auth.uid()
        OR p.landlord_id = auth.uid()
      )
  )
);
