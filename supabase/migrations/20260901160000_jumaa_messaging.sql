-- ============================================================
-- JUMAA PRIVATE MESSAGING
-- Tenant <-> Tenant
-- Tenant <-> Landlord
-- ============================================================

-- ------------------------------------------------------------
-- 1. CONVERSATIONS
-- ------------------------------------------------------------

create table if not exists public.conversations (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null
        references public.properties(id)
        on delete cascade,

    unit_id uuid
        references public.units(id)
        on delete set null,

    created_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- 2. CONVERSATION PARTICIPANTS
-- profile_id = Supabase Auth user UUID
-- ------------------------------------------------------------

create table if not exists public.conversation_participants (
    id uuid primary key default gen_random_uuid(),

    conversation_id uuid not null
        references public.conversations(id)
        on delete cascade,

    profile_id uuid not null
        references auth.users(id)
        on delete cascade,

    joined_at timestamptz not null default now(),

    unique (conversation_id, profile_id)
);


-- ------------------------------------------------------------
-- 3. MESSAGES
-- ------------------------------------------------------------

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),

    conversation_id uuid not null
        references public.conversations(id)
        on delete cascade,

    sender_id uuid not null
        references auth.users(id)
        on delete cascade,

    receiver_id uuid not null
        references auth.users(id)
        on delete cascade,

    message text not null
        check (length(trim(message)) > 0),

    status text not null default 'sent'
        check (
            status in (
                'sent',
                'delivered',
                'read'
            )
        ),

    created_at timestamptz not null default now(),

    delivered_at timestamptz,

    read_at timestamptz
);


-- ------------------------------------------------------------
-- 4. INDEXES
-- ------------------------------------------------------------

create index if not exists idx_conversations_property
    on public.conversations(property_id);

create index if not exists idx_conversation_participants_profile
    on public.conversation_participants(profile_id);

create index if not exists idx_conversation_participants_conversation
    on public.conversation_participants(conversation_id);

create index if not exists idx_messages_conversation_created
    on public.messages(conversation_id, created_at);

create index if not exists idx_messages_sender
    on public.messages(sender_id);

create index if not exists idx_messages_receiver
    on public.messages(receiver_id);


-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================

alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;


-- ============================================================
-- CLEAN EXISTING MESSAGING POLICIES
-- ============================================================

drop policy if exists "authenticated_can_create_conversations"
on public.conversations;

drop policy if exists "conversation_participants_can_view"
on public.conversations;

drop policy if exists "users_create_conversations"
on public.conversations;

drop policy if exists "users_view_own_conversations"
on public.conversations;

drop policy if exists "authenticated_can_add_conversation_participants"
on public.conversation_participants;

drop policy if exists "participants_can_view_participants"
on public.conversation_participants;

drop policy if exists "users_add_conversation_participants"
on public.conversation_participants;

drop policy if exists "users_view_conversation_participants"
on public.conversation_participants;

drop policy if exists "conversation_participants_can_send_messages"
on public.messages;

drop policy if exists "conversation_participants_can_view_messages"
on public.messages;

drop policy if exists "message_receiver_can_update_status"
on public.messages;

drop policy if exists "users_send_conversation_messages"
on public.messages;

drop policy if exists "users_view_conversation_messages"
on public.messages;


-- ============================================================
-- 6. CONVERSATIONS POLICIES
-- ============================================================

drop policy if exists "conversation_participants_can_view"
on public.conversations;

create policy "conversation_participants_can_view"
on public.conversations
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_participants cp
        where cp.conversation_id = conversations.id
          and cp.profile_id = auth.uid()
    )
);


drop policy if exists "authenticated_can_create_conversations"
on public.conversations;

create policy "authenticated_can_create_conversations"
on public.conversations
for insert
to authenticated
with check (
    exists (
        select 1
        from public.properties p
        where p.id = conversations.property_id
    )
);


-- ============================================================
-- 7. PARTICIPANT POLICIES
-- ============================================================

drop policy if exists "participants_can_view_participants"
on public.conversation_participants;

create policy "participants_can_view_participants"
on public.conversation_participants
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_participants mine
        where mine.conversation_id =
              conversation_participants.conversation_id
          and mine.profile_id = auth.uid()
    )
);


drop policy if exists "authenticated_can_add_conversation_participants"
on public.conversation_participants;

create policy "authenticated_can_add_conversation_participants"
on public.conversation_participants
for insert
to authenticated
with check (
    exists (
        select 1
        from public.conversations c
        where c.id = conversation_participants.conversation_id
    )
);


-- ============================================================
-- 8. MESSAGE SELECT
-- ============================================================

drop policy if exists "conversation_participants_can_view_messages"
on public.messages;

create policy "conversation_participants_can_view_messages"
on public.messages
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_participants cp
        where cp.conversation_id = messages.conversation_id
          and cp.profile_id = auth.uid()
    )
);


-- ============================================================
-- 9. MESSAGE INSERT
-- ============================================================

drop policy if exists "conversation_participants_can_send_messages"
on public.messages;

create policy "conversation_participants_can_send_messages"
on public.messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1
        from public.conversation_participants cp
        where cp.conversation_id = messages.conversation_id
          and cp.profile_id = auth.uid()
    )
    and exists (
        select 1
        from public.conversation_participants cp
        where cp.conversation_id = messages.conversation_id
          and cp.profile_id = messages.receiver_id
    )
);


-- ============================================================
-- 10. MESSAGE UPDATE
-- Used for delivered/read status.
-- ============================================================

drop policy if exists "message_receiver_can_update_status"
on public.messages;

create policy "message_receiver_can_update_status"
on public.messages
for update
to authenticated
using (
    receiver_id = auth.uid()
)
with check (
    receiver_id = auth.uid()
);


-- ============================================================
-- 11. REALTIME
-- ============================================================

do $$
begin
    alter publication supabase_realtime
        add table public.messages;
exception
    when duplicate_object then
        null;
end $$;
