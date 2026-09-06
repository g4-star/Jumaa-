-- ============================================================
-- JUMAA: Allow tenants to view their own tenant profile
-- ============================================================

DROP POLICY IF EXISTS tenants_view_own_profile
ON public.tenants;

CREATE POLICY tenants_view_own_profile
ON public.tenants
FOR SELECT
TO authenticated
USING (
    auth_user_id = auth.uid()
);

-- Allow a tenant to update only their own profile if needed
DROP POLICY IF EXISTS tenants_update_own_profile
ON public.tenants;

CREATE POLICY tenants_update_own_profile
ON public.tenants
FOR UPDATE
TO authenticated
USING (
    auth_user_id = auth.uid()
)
WITH CHECK (
    auth_user_id = auth.uid()
);
