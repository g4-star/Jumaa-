-- Fix tenant RLS for landlord booking approval
-- Landlords may only access tenant records belonging
-- to properties assigned to their landlord account.

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- SELECT
-- =========================================================

DROP POLICY IF EXISTS "landlords_view_property_tenants"
ON public.tenants;

CREATE POLICY "landlords_view_property_tenants"
ON public.tenants
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.properties p
        JOIN public.landlords l
          ON l.id = p.landlord_id
        WHERE p.id = tenants.property_id
          AND l.auth_user_id = auth.uid()
    )
);

-- =========================================================
-- INSERT
-- =========================================================

DROP POLICY IF EXISTS "landlords_insert_property_tenants"
ON public.tenants;

CREATE POLICY "landlords_insert_property_tenants"
ON public.tenants
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.properties p
        JOIN public.landlords l
          ON l.id = p.landlord_id
        WHERE p.id = tenants.property_id
          AND l.auth_user_id = auth.uid()
    )
);

-- =========================================================
-- UPDATE
-- =========================================================

DROP POLICY IF EXISTS "landlords_update_property_tenants"
ON public.tenants;

CREATE POLICY "landlords_update_property_tenants"
ON public.tenants
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.properties p
        JOIN public.landlords l
          ON l.id = p.landlord_id
        WHERE p.id = tenants.property_id
          AND l.auth_user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.properties p
        JOIN public.landlords l
          ON l.id = p.landlord_id
        WHERE p.id = tenants.property_id
          AND l.auth_user_id = auth.uid()
    )
);
