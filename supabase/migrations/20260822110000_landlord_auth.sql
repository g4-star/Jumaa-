-- ============================================================
-- JUMAA landlord authentication/profile support
-- ============================================================

-- Make sure profiles are linked to Supabase Auth users.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Allow authenticated landlords to read their own profile.
DROP POLICY IF EXISTS landlords_select_own ON public.profiles;

CREATE POLICY landlords_select_own
ON public.profiles
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  AND role = 'landlord'
);

-- Allow landlords to update their own profile.
DROP POLICY IF EXISTS landlords_update_own ON public.profiles;

CREATE POLICY landlords_update_own
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  id = auth.uid()
  AND role = 'landlord'
)
WITH CHECK (
  id = auth.uid()
  AND role = 'landlord'
);

-- Landlords can see properties assigned to them.
-- Your current properties table uses owner_id, so landlord
-- access should be based on the property assignment strategy.
DROP POLICY IF EXISTS landlords_view_assigned_properties
ON public.properties;

CREATE POLICY landlords_view_assigned_properties
ON public.properties
FOR SELECT
TO authenticated
USING (
  owner_id = auth.uid()
  OR owner_id IN (
    SELECT id
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'landlord'
  )
);

-- Landlords can see units belonging to their properties.
DROP POLICY IF EXISTS landlords_view_assigned_units
ON public.units;

CREATE POLICY landlords_view_assigned_units
ON public.units
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = units.property_id
      AND p.owner_id = auth.uid()
  )
);
