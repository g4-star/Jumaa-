-- ============================================================
-- JUMAA OWNER NOTIFICATIONS
-- Notifications sent to apartment owners by the JUMAA platform.
-- ============================================================

create table if not exists public.owner_notifications (
    id uuid primary key default gen_random_uuid(),

    owner_id uuid not null
        references public.profiles(id)
        on delete cascade,

    request_id uuid
        references public.owner_requests(id)
        on delete set null,

    title text not null,

    message text not null,

    notification_type text not null default 'general',

    is_read boolean not null default false,

    created_at timestamptz not null default now()
);

create index if not exists idx_owner_notifications_owner_id
on public.owner_notifications(owner_id);

create index if not exists idx_owner_notifications_created_at
on public.owner_notifications(created_at desc);

create index if not exists idx_owner_notifications_request_id
on public.owner_notifications(request_id);

alter table public.owner_notifications enable row level security;

-- Apartment owners can view their own notifications.
drop policy if exists "Owners can view their own notifications"
on public.owner_notifications;

create policy "Owners can view their own notifications"
on public.owner_notifications
for select
to authenticated
using (
    owner_id = auth.uid()
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'owner'
    )
);

-- Apartment owners can mark their own notifications as read.
drop policy if exists "Owners can update their own notifications"
on public.owner_notifications;

create policy "Owners can update their own notifications"
on public.owner_notifications
for update
to authenticated
using (
    owner_id = auth.uid()
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'owner'
    )
)
with check (
    owner_id = auth.uid()
    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'owner'
    )
);

-- JUMAA platform owner can create notifications.
drop policy if exists "JUMAA owners can create owner notifications"
on public.owner_notifications;

create policy "JUMAA owners can create owner notifications"
on public.owner_notifications
for insert
to authenticated
with check (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'jumaa_owner'
    )
);

-- JUMAA platform owner can view all owner notifications.
drop policy if exists "JUMAA owners can view owner notifications"
on public.owner_notifications;

create policy "JUMAA owners can view owner notifications"
on public.owner_notifications
for select
to authenticated
using (
    exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'jumaa_owner'
    )
);

