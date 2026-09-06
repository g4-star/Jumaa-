-- ============================================================
-- JUMAA: BLOCK OPERATIONAL NOTIFICATIONS FOR SUSPENDED PROPERTIES
-- ============================================================
--
-- A suspended property is operationally paused.
--
-- Tenant and landlord accounts remain active.
-- Their restrictions are derived from properties.is_suspended.
--
-- This migration prevents tenants and landlords from creating
-- property notifications while their property is suspended.
-- ============================================================

-- ------------------------------------------------------------
-- TENANT INSERT
-- ------------------------------------------------------------

drop policy if exists
"Tenants can create property notifications"
on public.notifications;

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
        join public.properties p
          on p.id = t.property_id
        where t.auth_user_id = auth.uid()
          and t.property_id = notifications.property_id
          and coalesce(p.is_suspended, false) = false
    )
);

-- ------------------------------------------------------------
-- LANDLORD INSERT
-- ------------------------------------------------------------

drop policy if exists
"Landlords can create property notifications"
on public.notifications;

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
          and coalesce(p.is_suspended, false) = false
    )
);

-- ============================================================
-- READ
--
-- Keep existing read behavior. The dashboard navigation already
-- prevents suspended tenants/landlords from entering operational
-- pages.
-- ============================================================
