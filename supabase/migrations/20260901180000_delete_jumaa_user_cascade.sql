-- ============================================================
-- JUMAA: COMPLETE USER DELETION
-- ============================================================
--
-- Called by the JUMAA owner dashboard.
--
-- Deletes:
--   profiles
--   auth.users
--   landlords
--   properties
--   property images/videos
--   units
--   unit images
--   booking requests
--   tenants
--   payments
--   payment reminders
--   notifications
--   chat/messages through property cascades
--   subscriptions
--   subscription payments
--
-- ============================================================

create or replace function public.delete_jumaa_user(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_caller uuid;
    v_role text;

    v_property_count integer := 0;
    v_landlord_exists boolean := false;
    v_profile_exists boolean := false;
begin
    -- --------------------------------------------------------
    -- 1. Identify caller
    -- --------------------------------------------------------
    v_caller := auth.uid();

    if v_caller is null then
        raise exception 'Not authenticated';
    end if;

    -- --------------------------------------------------------
    -- 2. Only JUMAA owner may delete users
    -- --------------------------------------------------------
    select role
    into v_role
    from public.profiles
    where id = v_caller;

    if v_role is null or v_role <> 'jumaa_owner' then
        raise exception 'Only the JUMAA owner can delete users';
    end if;

    -- --------------------------------------------------------
    -- 3. Prevent deleting the JUMAA owner account
    -- --------------------------------------------------------
    if p_user_id = v_caller then
        raise exception 'The JUMAA owner account cannot be deleted';
    end if;

    -- --------------------------------------------------------
    -- 4. Verify target exists
    -- --------------------------------------------------------
    select exists(
        select 1
        from public.profiles
        where id = p_user_id
    )
    into v_profile_exists;

    if not v_profile_exists then
        raise exception 'User does not exist';
    end if;

    -- --------------------------------------------------------
    -- 5. Count properties owned by this user
    -- --------------------------------------------------------
    select count(*)
    into v_property_count
    from public.properties
    where owner_id = p_user_id;

    -- --------------------------------------------------------
    -- 6. Delete subscription records
    -- --------------------------------------------------------
    delete from public.subscription_payments
    where owner_id = p_user_id;

    delete from public.subscriptions
    where owner_id = p_user_id;

    -- --------------------------------------------------------
    -- 7. Delete properties owned by this user
    --
    -- This intentionally uses owner_id because your schema
    -- retained owner_id for compatibility.
    --
    -- Property children using ON DELETE CASCADE will then be
    -- removed automatically:
    --
    -- property_images
    -- property_videos
    -- units
    -- booking_requests
    -- tenants
    -- payments
    -- payment_reminders
    -- notifications
    -- chat_messages
    -- conversations
    -- etc.
    -- --------------------------------------------------------
    delete from public.properties
    where owner_id = p_user_id;

    -- --------------------------------------------------------
    -- 8. Delete landlord record
    --
    -- Your migration establishes landlords.id as the auth
    -- user UUID.
    -- --------------------------------------------------------
    delete from public.landlords
    where id = p_user_id;

    -- --------------------------------------------------------
    -- 9. Delete profile
    -- --------------------------------------------------------
    delete from public.profiles
    where id = p_user_id;

    -- --------------------------------------------------------
    -- 10. Finally delete Supabase Auth account
    -- --------------------------------------------------------
    delete from auth.users
    where id = p_user_id;

    -- --------------------------------------------------------
    -- 11. Return useful information to Flutter
    -- --------------------------------------------------------
    return jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'properties_deleted', v_property_count
    );

exception
    when others then
        raise exception 'JUMAA user deletion failed: %', sqlerrm;
end;
$$;


-- ------------------------------------------------------------
-- Only authenticated users can execute the function.
-- Actual authorization is checked inside the function.
-- ------------------------------------------------------------

revoke all on function public.delete_jumaa_user(uuid)
from public;

grant execute on function public.delete_jumaa_user(uuid)
to authenticated;
