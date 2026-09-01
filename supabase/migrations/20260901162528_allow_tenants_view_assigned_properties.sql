CREATE POLICY "tenants_view_assigned_properties"
ON public.properties
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = auth.uid()
      AND t.property_id = properties.id
      AND t.account_status = 'active'
  )
);
