-- ============================================================
-- JUMAA PROPERTY-WIDE NOTIFICATIONS
-- ============================================================
-- Existing notifications use:
--     user_id -> profiles.id
--
-- This migration adds:
--     property_id
--     sender_type
--     sender_name
--
-- Tenants and landlords can create notifications.
-- Members of the same property can read them.
-- Admins have no INSERT policy.
-- ============================================================


-- ============================================================
-- 1. ADD PROPERTY ASSOCIATION
-- ============================================================

alter table public.notifications
add column if not exists property_id uuid
references public.properties(id)
on delete cascade;


-- ============================================================
-- 2. ADD SENDER INFORMATION
-- ============================================================

alter table public.notifications
add column if not exists sender_type text;

alter table public.notifications
add column if not exists sender_name text;


-- ============================================================
-- 3. INDEX
-- ============================================================

create index if not exists idx_notifications_property
on public.notifications(property_id);


-- ============================================================
-- 4. BACKFILL EXISTING NOTIFICATIONS
--
-- Existing notifications use user_id -> profiles.id.
--
-- First try to associate the notification with a property
-- through the landlord's profile/property relationship.
-- ============================================================

update public.notifications n
set property_id = p.id
from public.properties p
where n.user_id = p.owner_id
  and n.property_id is null;


-- ============================================================
-- 5. BACKFILL THROUGH LANDLORD AUTH LINK
-- ============================================================

update public.notifications n
set property_id = p.id
from public.properties p
join public.landlords l
  on l.id = p.landlord_id
where n.user_id = l.auth_user_id
  and n.property_id is null;


-- ============================================================
-- 6. BACKFILL THROUGH TENANT AUTH LINK
-- ============================================================

update public.notifications n
set property_id = t.property_id
from public.tenants t
where n.user_id = t.auth_user_id
  and n.property_id is null;


-- ============================================================
-- 7. ENABLE RLS
-- ============================================================

alter table public.notifications enable row level security;


-- ============================================================
-- 8. REMOVE OUR PREVIOUS POLICIES IF THEY EXIST
-- ============================================================

drop policy if exists
"Authenticated users can view apartment notifications"
on public.notifications;

drop policy if exists
"Tenants can create apartment notifications"
on public.notifications;

drop policy if exists
"notifications_insert_tenant"
on public.notifications;

drop policy if exists
"notifications_insert_landlord"
on public.notifications;

drop policy if exists
"Users can view property notifications"
on public.notifications;

drop policy if exists
"Tenants can create property notifications"
on public.notifications;

drop policy if exists
"Landlords can create property notifications"
on public.notifications;


-- ============================================================
-- 9. READ POLICY
--
-- A user may read notifications if they belong to the
-- notification's property.
--
-- Tenant:
--     tenants.auth_user_id = auth.uid()
--
-- Landlord through modern profile system:
--     properties.owner_id = auth.uid()
--
-- Landlord through existing landlord system:
--     landlords.auth_user_id = auth.uid()
-- ============================================================

create policy "Users can view property notifications"
on public.notifications
for select
to authenticated
using (

    -- Tenant
    property_id in (
        select t.property_id
        from public.tenants t
        where t.auth_user_id = auth.uid()
    )

    or

    -- Landlord through properties.owner_id
    property_id in (
        select p.id
        from public.properties p
        where p.owner_id = auth.uid()
    )

    or

    -- Landlord through landlords.auth_user_id
    property_id in (
        select p.id
        from public.properties p
        join public.landlords l
          on l.id = p.landlord_id
        where l.auth_user_id = auth.uid()
    )
);


-- ============================================================
-- 10. TENANT CREATE
-- ============================================================

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


-- ============================================================
-- 11. LANDLORD CREATE
--
-- Supports BOTH landlord authentication models.
-- ============================================================

create policy "Landlords can create property notifications"
on public.notifications
for insert
to authenticated
with check (

    user_id = auth.uid()

    and property_id is not null

    and (
        exists (
            select 1
            from public.properties p
            where p.id = notifications.property_id
              and p.owner_id = auth.uid()
        )

        or

        exists (
            select 1
            from public.properties p
            join public.landlords l
              on l.id = p.landlord_id
            where p.id = notifications.property_id
              and l.auth_user_id = auth.uid()
        )
    )
);


-- ============================================================
-- 12. NO ADMIN INSERT POLICY
-- ============================================================
--
-- Admins can monitor notifications through whatever existing
-- admin access policy they already have.
--
-- This migration intentionally creates NO admin INSERT policy.
--
-- ============================================================

