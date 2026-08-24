-- ============================================================
-- JUMAA LANDLORD AUTHENTICATION
-- ============================================================
-- Landlords are represented by rows in public.profiles.
-- profiles.id corresponds to auth.users.id.
-- Properties belong to landlords through properties.owner_id.
-- Units belong to properties.

-- ============================================================
-- PROFILE AUTH ID
-- ============================================================

alter table public.profiles
  alter column id drop default;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.units enable row level security;

-- ============================================================
-- LANDLORD PROFILE
-- A landlord can read only their own profile.
-- ============================================================

drop policy if exists "landlords_select_own" on public.profiles;

create policy "landlords_select_own"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  and role = 'landlord'
);

-- ============================================================
-- LANDLORD PROPERTIES
-- A landlord can read only properties they own.
-- ============================================================

drop policy if exists "properties_select_own" on public.properties;

create policy "properties_select_own"
on public.properties
for select
to authenticated
using (
  owner_id = auth.uid()
);

-- ============================================================
-- LANDLORD UNITS
-- A landlord can read units belonging to their properties.
-- ============================================================

drop policy if exists "units_select_own" on public.units;

create policy "units_select_own"
on public.units
for select
to authenticated
using (
  exists (
    select 1
    from public.properties
    where properties.id = units.property_id
      and properties.owner_id = auth.uid()
  )
);
