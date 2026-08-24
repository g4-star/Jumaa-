-- ============================================================
-- JUMAA DATABASE SCHEMA
-- Property -> Units -> Bookings -> Tenants -> Payments
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- 1. LANDLORDS / OWNERS
-- ============================================================

create table if not exists landlords (
    id uuid primary key default gen_random_uuid(),
    full_name text not null,
    email text not null unique,
    phone text not null,
    created_at timestamptz not null default now()
);

-- ============================================================
-- 2. PROPERTIES
-- One property can contain many units.
-- Example: Greenview Apartments
-- ============================================================

create table if not exists properties (
    id uuid primary key default gen_random_uuid(),

    landlord_id uuid not null
        references landlords(id)
        on delete cascade,

    name text not null,
    description text default '',
    location text not null,
    address text default '',

    latitude double precision,
    longitude double precision,

    amenities text[] not null default '{}',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- Payment destination for this property
    payment_method text not null default 'till'
        check (
            payment_method in (
                'till',
                'paybill'
            )
        ),

    mpesa_till_number text default '',
    mpesa_paybill_number text default '',
    mpesa_account_number text default '',
    payments_enabled boolean not null default true
);

-- ============================================================
-- 3. PROPERTY IMAGES
-- Many images can belong to one property.
-- ============================================================

create table if not exists property_images (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references properties(id)
        on delete cascade,

    image_url text not null,
    display_order integer not null default 0,

    created_at timestamptz not null default now()
);

-- ============================================================
-- 4. PROPERTY VIDEOS
-- ============================================================

create table if not exists property_videos (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references properties(id)
        on delete cascade,

    video_url text not null,
    display_order integer not null default 0,

    created_at timestamptz not null default now()
);

-- ============================================================
-- 5. UNITS / ROOMS
-- Example:
-- Greenview Apartments
--   A101
--   A102
--   A103
-- ============================================================

create table if not exists units (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references properties(id)
        on delete cascade,

    unit_number text not null,
    unit_type text not null,
    description text default '',

    monthly_rent numeric(12,2) not null default 0,
    service_charge numeric(12,2) not null default 0,

    status text not null default 'vacant'
        check (status in ('vacant', 'occupied', 'reserved', 'maintenance')),

    floor text default '',
    bedrooms integer default 0,
    bathrooms integer default 0,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    unique(property_id, unit_number)
);

-- ============================================================
-- 6. UNIT IMAGES
-- ============================================================

create table if not exists unit_images (
    id uuid primary key default gen_random_uuid(),

    unit_id uuid not null
        references units(id)
        on delete cascade,

    image_url text not null,
    display_order integer not null default 0,

    created_at timestamptz not null default now()
);

-- ============================================================
-- 7. BOOKING REQUESTS
-- A public user can submit a booking request without
-- already having a tenant account.
-- ============================================================

create table if not exists booking_requests (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references properties(id)
        on delete cascade,

    unit_id uuid not null
        references units(id)
        on delete cascade,

    applicant_name text not null,
    applicant_email text not null,
    applicant_phone text not null,

    national_id text,
    occupation text,
    employer text,

    preferred_move_in_date date,

    additional_notes text default '',

    status text not null default 'pending'
        check (
            status in (
                'pending',
                'approved',
                'rejected',
                'cancelled'
            )
        ),

    landlord_notes text default '',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================================
-- 8. TENANTS
-- Tenant account is created after landlord approval.
-- ============================================================

create table if not exists tenants (
    id uuid primary key default gen_random_uuid(),

    booking_request_id uuid unique
        references booking_requests(id)
        on delete set null,

    property_id uuid not null
        references properties(id)
        on delete cascade,

    unit_id uuid not null
        references units(id)
        on delete cascade,

    full_name text not null,
    email text not null unique,
    phone text not null,

    -- This is for the application's tenant profile.
    -- Authentication credentials should ultimately be
    -- handled by Supabase Auth rather than storing passwords here.
    account_status text not null default 'active'
        check (
            account_status in (
                'active',
                'suspended',
                'inactive'
            )
        ),

    move_in_date date,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================================
-- 9. RENT / PAYMENT RECORDS
-- ============================================================

create table if not exists payments (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null
        references tenants(id)
        on delete cascade,

    property_id uuid not null
        references properties(id)
        on delete cascade,

    unit_id uuid not null
        references units(id)
        on delete cascade,

    amount numeric(12,2) not null check (amount > 0),

    payment_type text not null default 'rent'
        check (
            payment_type in (
                'rent',
                'service_charge',
                'deposit',
                'other'
            )
        ),

    status text not null default 'pending'
        check (
            status in (
                'pending',
                'processing',
                'paid',
                'failed',
                'cancelled'
            )
        ),

    due_date date not null,
    payment_date timestamptz,

    reference text,

    -- Snapshot of where this payment was directed.
    -- This preserves the destination even if the property's
    -- payment settings are changed later.
    payment_method text not null default 'till'
        check (
            payment_method in (
                'till',
                'paybill'
            )
        ),

    payment_destination text default '',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================================
-- 10. PAYMENT REMINDERS
-- ============================================================

create table if not exists payment_reminders (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null
        references tenants(id)
        on delete cascade,

    payment_id uuid not null
        references payments(id)
        on delete cascade,

    reminder_type text not null
        check (
            reminder_type in (
                'five_days_before',
                'one_day_before',
                'due_today',
                'overdue'
            )
        ),

    scheduled_for timestamptz not null,
    sent_at timestamptz,

    created_at timestamptz not null default now(),

    unique(payment_id, reminder_type)
);

-- ============================================================
-- 11. NOTIFICATIONS
-- ============================================================

create table if not exists notifications (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid
        references tenants(id)
        on delete cascade,

    landlord_id uuid
        references landlords(id)
        on delete cascade,

    booking_request_id uuid
        references booking_requests(id)
        on delete cascade,

    title text not null,
    message text not null,

    notification_type text not null default 'general',

    is_read boolean not null default false,

    created_at timestamptz not null default now(),

    check (
        tenant_id is not null
        or landlord_id is not null
    )
);

-- ============================================================
-- 12. PROPERTY CHAT MESSAGES
-- Tenant/applicant can communicate with landlord.
-- ============================================================

create table if not exists chat_messages (
    id uuid primary key default gen_random_uuid(),

    booking_request_id uuid
        references booking_requests(id)
        on delete cascade,

    property_id uuid not null
        references properties(id)
        on delete cascade,

    sender_type text not null
        check (
            sender_type in (
                'applicant',
                'tenant',
                'landlord'
            )
        ),

    sender_name text not null,
    sender_email text,

    message text not null,

    created_at timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================

create index if not exists idx_properties_landlord
    on properties(landlord_id);

create index if not exists idx_property_images_property
    on property_images(property_id);

create index if not exists idx_property_videos_property
    on property_videos(property_id);

create index if not exists idx_units_property
    on units(property_id);

create index if not exists idx_units_status
    on units(status);

create index if not exists idx_booking_requests_property
    on booking_requests(property_id);

create index if not exists idx_booking_requests_unit
    on booking_requests(unit_id);

create index if not exists idx_booking_requests_status
    on booking_requests(status);

create index if not exists idx_tenants_property
    on tenants(property_id);

create index if not exists idx_tenants_unit
    on tenants(unit_id);

create index if not exists idx_payments_tenant
    on payments(tenant_id);

create index if not exists idx_payments_due_date
    on payments(due_date);

create index if not exists idx_notifications_tenant
    on notifications(tenant_id);

create index if not exists idx_notifications_landlord
    on notifications(landlord_id);

create index if not exists idx_chat_booking
    on chat_messages(booking_request_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

create or replace function update_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists properties_updated_at on properties;

create trigger properties_updated_at
before update on properties
for each row
execute function update_updated_at();

drop trigger if exists units_updated_at on units;

create trigger units_updated_at
before update on units
for each row
execute function update_updated_at();

drop trigger if exists booking_requests_updated_at
on booking_requests;

create trigger booking_requests_updated_at
before update on booking_requests
for each row
execute function update_updated_at();

drop trigger if exists tenants_updated_at on tenants;

create trigger tenants_updated_at
before update on tenants
for each row
execute function update_updated_at();

drop trigger if exists payments_updated_at on payments;

create trigger payments_updated_at
before update on payments
for each row
execute function update_updated_at();

-- ============================================================
-- DONE
-- ============================================================

-- ============================================================
-- SUPABASE AUTH / LANDLORD LINK
-- ============================================================

-- For existing databases, make landlord IDs correspond to
-- Supabase Auth user IDs.
--
-- IMPORTANT:
-- This migration is intended for a fresh/controlled database.
-- Existing landlord records should be migrated before enforcing
-- this relationship.

