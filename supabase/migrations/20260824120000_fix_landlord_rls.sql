-- ============================================================
-- JUMAA
-- MIGRATE LANDLORD ARCHITECTURE
--
-- OLD:
--   auth.users
--       ↓
--   profiles
--       ↓
--   properties.owner_id
--       ↓
--   units
--
-- NEW:
--   auth.users
--       ↓
--   landlords
--       ↓
--   properties.landlord_id
--       ↓
--   units
--
-- IMPORTANT:
--   Existing profiles, properties and units are preserved.
--   owner_id is temporarily retained for compatibility.
-- ============================================================


-- ============================================================
-- 1. CREATE LANDLORDS TABLE
-- ============================================================

create table if not exists public.landlords (
    id uuid primary key,
    full_name text not null default '',
    email text not null default '',
    phone text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint landlords_id_fkey
        foreign key (id)
        references auth.users(id)
        on delete cascade
);


-- ============================================================
-- 2. CREATE LANDLORD RECORDS FROM EXISTING PROFILES
--
-- We preserve existing landlord/owner users.
-- We do NOT delete or modify profiles.
-- ============================================================

insert into public.landlords (
    id,
    full_name,
    email,
    phone
)
select
    p.id,
    coalesce(p.full_name, ''),
    coalesce(p.email, ''),
    coalesce(p.phone, '')
from public.profiles p
where p.role in ('landlord', 'owner')
on conflict (id) do update
set
    full_name = excluded.full_name,
    email = excluded.email,
    phone = excluded.phone,
    updated_at = now();


-- ============================================================
-- 3. ADD landlord_id TO PROPERTIES
-- ============================================================

alter table public.properties
    add column if not exists landlord_id uuid;


-- ============================================================
-- 4. MIGRATE EXISTING PROPERTY OWNERSHIP
--
-- Old:
--     properties.owner_id -> profiles.id
--
-- New:
--     properties.landlord_id -> landlords.id
--
-- Existing properties are preserved.
-- ============================================================

update public.properties
set landlord_id = owner_id
where landlord_id is null
  and owner_id is not null;


-- ============================================================
-- 5. CREATE NEW FOREIGN KEY
-- ============================================================

alter table public.properties
    drop constraint if exists properties_landlord_id_fkey;

alter table public.properties
    add constraint properties_landlord_id_fkey
    foreign key (landlord_id)
    references public.landlords(id)
    on delete set null;


-- ============================================================
-- 6. INDEX landlord_id
-- ============================================================

create index if not exists idx_properties_landlord
    on public.properties(landlord_id);


-- ============================================================
-- 7. ENABLE RLS
-- ============================================================

alter table public.landlords enable row level security;
alter table public.properties enable row level security;
alter table public.units enable row level security;


-- ============================================================
-- 8. REMOVE OLD LANDLORD PROPERTY POLICIES
-- ============================================================

drop policy if exists "properties_select_own"
    on public.properties;

drop policy if exists "landlords_view_assigned_properties"
    on public.properties;

drop policy if exists "landlords_view_own_properties"
    on public.properties;

drop policy if exists "landlords_insert_own_properties"
    on public.properties;

drop policy if exists "landlords_update_own_properties"
    on public.properties;

drop policy if exists "landlords_delete_own_properties"
    on public.properties;


-- ============================================================
-- 9. PROPERTY POLICIES
-- ============================================================

create policy "landlords_view_own_properties"
on public.properties
for select
to authenticated
using (
    landlord_id = auth.uid()
);


create policy "landlords_insert_own_properties"
on public.properties
for insert
to authenticated
with check (
    landlord_id = auth.uid()
);


create policy "landlords_update_own_properties"
on public.properties
for update
to authenticated
using (
    landlord_id = auth.uid()
)
with check (
    landlord_id = auth.uid()
);


create policy "landlords_delete_own_properties"
on public.properties
for delete
to authenticated
using (
    landlord_id = auth.uid()
);


-- ============================================================
-- 10. REMOVE OLD UNIT POLICIES
-- ============================================================

drop policy if exists "units_select_own"
    on public.units;

drop policy if exists "landlords_view_assigned_units"
    on public.units;

drop policy if exists "landlords_view_own_units"
    on public.units;

drop policy if exists "landlords_insert_own_units"
    on public.units;

drop policy if exists "landlords_update_own_units"
    on public.units;

drop policy if exists "landlords_delete_own_units"
    on public.units;


-- ============================================================
-- 11. UNIT POLICIES
-- ============================================================

create policy "landlords_view_own_units"
on public.units
for select
to authenticated
using (
    exists (
        select 1
        from public.properties p
        where p.id = units.property_id
          and p.landlord_id = auth.uid()
    )
);


create policy "landlords_insert_own_units"
on public.units
for insert
to authenticated
with check (
    exists (
        select 1
        from public.properties p
        where p.id = units.property_id
          and p.landlord_id = auth.uid()
    )
);


create policy "landlords_update_own_units"
on public.units
for update
to authenticated
using (
    exists (
        select 1
        from public.properties p
        where p.id = units.property_id
          and p.landlord_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.properties p
        where p.id = units.property_id
          and p.landlord_id = auth.uid()
    )
);


create policy "landlords_delete_own_units"
on public.units
for delete
to authenticated
using (
    exists (
        select 1
        from public.properties p
        where p.id = units.property_id
          and p.landlord_id = auth.uid()
    )
);


-- ============================================================
-- 12. LANDLORD RLS
-- ============================================================

drop policy if exists "landlords_select_own"
    on public.landlords;

drop policy if exists "landlords_insert_own"
    on public.landlords;

drop policy if exists "landlords_update_own"
    on public.landlords;


create policy "landlords_select_own"
on public.landlords
for select
to authenticated
using (
    id = auth.uid()
);


create policy "landlords_insert_own"
on public.landlords
for insert
to authenticated
with check (
    id = auth.uid()
);


create policy "landlords_update_own"
on public.landlords
for update
to authenticated
using (
    id = auth.uid()
)
with check (
    id = auth.uid()
);


-- ============================================================
-- 13. LANDLORD INDEX
-- ============================================================

create index if not exists idx_landlords_email
    on public.landlords(email);

create index if not exists idx_landlords_phone
    on public.landlords(phone);


-- ============================================================
-- END
--
-- NOTE:
-- properties.owner_id is intentionally NOT removed yet.
-- It will be removed only after we verify that nothing in
-- JUMAA still depends on it.
-- ============================================================
