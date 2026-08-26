-- ============================================================
-- JUMAA PROPERTY NOTIFICATION RLS FIX
-- ============================================================
-- The actual notifications table uses:
--   user_id
--   property_id
--   type
--
-- Landlords are identified through:
--   landlords.auth_user_id
--
-- Tenants are identified through:
--   tenants.auth_user_id
-- ============================================================

-- ------------------------------------------------------------
-- Remove the policies created by the previous migration
-- ------------------------------------------------------------

drop policy if exists
"Users can view property notifications"
on public.notifications;

drop policy if exists
"Tenants can create property notifications"
on public.notifications;

drop policy if exists
"Landlords can create property notifications"
on public.notifications;

-- ------------------------------------------------------------
-- READ
--
-- A tenant can read notifications for their property.
-- A landlord can read notifications for their property.
-- ------------------------------------------------------------

create policy "Users can view property notifications"
on public.notifications
for select
to authenticated
using (
    property_id in (
        select t.property_id
        from public.tenants t
        where t.auth_user_id = auth.uid()
    )
    or
    property_id in (
        select p.id
        from public.properties p
        join public.landlords l
          on l.id = p.landlord_id
        where l.auth_user_id = auth.uid()
    )
);

-- ------------------------------------------------------------
-- TENANT CREATE
-- ------------------------------------------------------------

create policy "Tenants can create property notifications"
on public.notifications
for insert
to authenticated
with check (
    user_id = auth.uid()
    and property_id is not null
    and exists (
        select 1
        from public.tenants t
        where t.auth_user_id = auth.uid()
          and t.property_id = notifications.property_id
    )
);

-- ------------------------------------------------------------
-- LANDLORD CREATE
-- ------------------------------------------------------------

create policy "Landlords can create property notifications"
on public.notifications
for insert
to authenticated
with check (
    user_id = auth.uid()
    and property_id is not null
    and exists (
        select 1
        from public.properties p
        join public.landlords l
          on l.id = p.landlord_id
        where p.id = notifications.property_id
          and l.auth_user_id = auth.uid()
    )
);

-- ============================================================
-- ADMIN IS READ-ONLY FOR THIS FEATURE
-- ============================================================
-- No admin INSERT policy is created.
-- ============================================================
