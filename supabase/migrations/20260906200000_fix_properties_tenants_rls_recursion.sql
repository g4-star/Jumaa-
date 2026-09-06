-- ============================================================
-- JUMAA: Fix properties <-> tenants RLS recursion
-- ============================================================

-- ------------------------------------------------------------
-- 1. Helper: determine whether the authenticated user is the
--    landlord assigned to a property.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_landlord_of_property(
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
        FROM public.properties p
        JOIN public.landlords l
          ON l.id = p.landlord_id
        WHERE p.id = p_property_id
          AND l.auth_user_id = p_user_id
    );
$$;


-- ------------------------------------------------------------
-- 2. Helper: determine whether the authenticated user is an
--    active tenant of a property.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_tenant_of_property(
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
    );
$$;


-- ------------------------------------------------------------
-- 3. Lock down function execution.
-- ------------------------------------------------------------

REVOKE ALL ON FUNCTION public.is_landlord_of_property(uuid, uuid)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.is_tenant_of_property(uuid, uuid)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_landlord_of_property(uuid, uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_tenant_of_property(uuid, uuid)
TO authenticated;


-- ------------------------------------------------------------
-- 4. Remove the recursive properties policy.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS tenants_view_assigned_properties
ON public.properties;


-- ------------------------------------------------------------
-- 5. Re-create tenant property access using the helper.
--    This no longer directly queries tenants from the
--    properties RLS policy.
-- ------------------------------------------------------------

CREATE POLICY tenants_view_assigned_properties
ON public.properties
FOR SELECT
TO authenticated
USING (
    public.is_tenant_of_property(id, auth.uid())
);


-- ------------------------------------------------------------
-- 6. Replace landlord tenant policies so they no longer
--    directly query properties from the tenants RLS policy.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS landlords_view_property_tenants
ON public.tenants;

DROP POLICY IF EXISTS landlords_insert_property_tenants
ON public.tenants;

DROP POLICY IF EXISTS landlords_update_property_tenants
ON public.tenants;


CREATE POLICY landlords_view_property_tenants
ON public.tenants
FOR SELECT
TO authenticated
USING (
    public.is_landlord_of_property(property_id, auth.uid())
);


CREATE POLICY landlords_insert_property_tenants
ON public.tenants
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_landlord_of_property(property_id, auth.uid())
);


CREATE POLICY landlords_update_property_tenants
ON public.tenants
FOR UPDATE
TO authenticated
USING (
    public.is_landlord_of_property(property_id, auth.uid())
)
WITH CHECK (
    public.is_landlord_of_property(property_id, auth.uid())
);


-- ============================================================
-- End
-- ============================================================
