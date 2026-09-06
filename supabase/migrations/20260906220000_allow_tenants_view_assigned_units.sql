-- Allow tenants to view only the unit assigned to their tenant account.
CREATE POLICY "tenants_view_assigned_units"
ON public.units
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.unit_id = units.id
      AND t.auth_user_id = auth.uid()
  )
);
