-- ============================================================
-- JUMAA MESSAGING RLS FIX
-- Prevent recursive RLS on conversation_participants
-- ============================================================

-- ------------------------------------------------------------
-- 1. SECURITY DEFINER HELPER
-- ------------------------------------------------------------

create or replace function public.is_conversation_participant(
    p_conversation_id uuid,
    p_profile_id uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (
        select 1
        from public.conversation_participants cp
        where cp.conversation_id = p_conversation_id
          and cp.profile_id = p_profile_id
    );
$$;

revoke all on function public.is_conversation_participant(uuid, uuid)
from public;

grant execute on function public.is_conversation_participant(uuid, uuid)
to authenticated;


-- ============================================================
-- 2. REMOVE RECURSIVE POLICIES
-- ============================================================

drop policy if exists "participants_can_view_participants"
on public.conversation_participants;

drop policy if exists "authenticated_can_add_conversation_participants"
on public.conversation_participants;

drop policy if exists "users_add_conversation_participants"
on public.conversation_participants;

drop policy if exists "users_view_conversation_participants"
on public.conversation_participants;


drop policy if exists "conversation_participants_can_view"
on public.conversations;

drop policy if exists "authenticated_can_create_conversations"
on public.conversations;

drop policy if exists "users_view_own_conversations"
on public.conversations;

drop policy if exists "users_create_conversations"
on public.conversations;


drop policy if exists "conversation_participants_can_view_messages"
on public.messages;

drop policy if exists "conversation_participants_can_send_messages"
on public.messages;

drop policy if exists "message_receiver_can_update_status"
on public.messages;

drop policy if exists "users_view_conversation_messages"
on public.messages;

drop policy if exists "users_send_conversation_messages"
on public.messages;


-- ============================================================
-- 3. CONVERSATION PARTICIPANTS
-- ============================================================

create policy "jumaa_users_view_conversation_participants"
on public.conversation_participants
for select
to authenticated
using (
    public.is_conversation_participant(
        conversation_participants.conversation_id,
        auth.uid()
    )
);


create policy "jumaa_users_add_conversation_participants"
on public.conversation_participants
for insert
to authenticated
with check (
    profile_id = auth.uid()
    or public.is_conversation_participant(
        conversation_participants.conversation_id,
        auth.uid()
    )
);


-- ============================================================
-- 4. CONVERSATIONS
-- ============================================================

create policy "jumaa_users_view_own_conversations"
on public.conversations
for select
to authenticated
using (
    public.is_conversation_participant(
        conversations.id,
        auth.uid()
    )
);


create policy "jumaa_users_create_conversations"
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
-- 5. MESSAGES
-- ============================================================

create policy "jumaa_users_view_conversation_messages"
on public.messages
for select
to authenticated
using (
    public.is_conversation_participant(
        messages.conversation_id,
        auth.uid()
    )
);


create policy "jumaa_users_send_conversation_messages"
on public.messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and public.is_conversation_participant(
        messages.conversation_id,
        auth.uid()
    )
    and public.is_conversation_participant(
        messages.conversation_id,
        messages.receiver_id
    )
);


create policy "jumaa_message_receiver_update_status"
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
-- 6. REALTIME
-- ============================================================

do $$
begin
    alter publication supabase_realtime
        add table public.messages;
exception
    when duplicate_object then
        null;
end $$;
