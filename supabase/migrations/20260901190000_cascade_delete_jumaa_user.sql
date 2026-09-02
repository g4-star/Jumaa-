-- ============================================================
-- JUMAA OWNER CASCADE DELETE
--
-- Deletes an apartment owner and the complete ecosystem owned
-- by that owner.
--
-- Only a JUMAA platform owner (role = jumaa_owner) can execute.
-- ============================================================

create or replace function public.delete_jumaa_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    property_ids uuid[] := '{}';
    landlord_ids uuid[] := '{}';
    landlord_auth_ids uuid[] := '{}';
    tenant_auth_ids uuid[] := '{}';

    deleted_property_count integer := 0;
    deleted_landlord_count integer := 0;
    deleted_tenant_auth_count integer := 0;
    deleted_landlord_auth_count integer := 0;
begin
    -- ========================================================
    -- 1. Validate target
    -- ========================================================

    if p_user_id is null then
        raise exception 'User ID is required';
    end if;

    -- Only the JUMAA platform owner may perform this operation.
    if not exists (
        select 1
        from public.profiles
        where id = auth.uid()
          and role = 'jumaa_owner'
    ) then
        raise exception 'Only the JUMAA owner can delete users';
    end if;

    -- Never allow the currently logged-in JUMAA owner to delete
    -- their own account.
    if p_user_id = auth.uid() then
        raise exception 'You cannot delete the account currently in use';
    end if;

    -- The target must actually be an apartment owner.
    if not exists (
        select 1
        from public.profiles
        where id = p_user_id
          and role = 'owner'
    ) then
        raise exception 'Target user is not an apartment owner';
    end if;

    -- ========================================================
    -- 2. Collect properties owned by this owner
    -- ========================================================

    select coalesce(array_agg(id), '{}')
    into property_ids
    from public.properties
    where owner_id = p_user_id;

    deleted_property_count :=
        coalesce(array_length(property_ids, 1), 0);

    -- ========================================================
    -- 3. Collect landlords attached to those properties
    -- ========================================================

    if deleted_property_count > 0 then

        select coalesce(array_agg(distinct landlord_id), '{}')
        into landlord_ids
        from public.properties
        where owner_id = p_user_id
          and landlord_id is not null;

        -- Collect both possible Auth references.
        select coalesce(array_agg(distinct x.auth_id), '{}')
        into landlord_auth_ids
        from (
            select l.id as auth_id
            from public.landlords l
            where l.id = any(landlord_ids)

            union

            select l.auth_user_id as auth_id
            from public.landlords l
            where l.id = any(landlord_ids)
              and l.auth_user_id is not null
        ) x;

        -- ====================================================
        -- 4. Collect tenant Auth accounts
        -- ====================================================

        select coalesce(array_agg(distinct t.auth_user_id), '{}')
        into tenant_auth_ids
        from public.tenants t
        where t.property_id = any(property_ids)
          and t.auth_user_id is not null;

        -- ====================================================
        -- 5. Delete subscription payment records
        -- ====================================================

        if to_regclass('public.subscription_payments') is not null then
            delete from public.subscription_payments
            where property_id = any(property_ids)
               or owner_id = p_user_id;
        end if;

        -- ====================================================
        -- 6. Delete subscriptions
        -- ====================================================

        if to_regclass('public.subscriptions') is not null then
            delete from public.subscriptions
            where property_id = any(property_ids)
               or owner_id = p_user_id;
        end if;

        -- ====================================================
        -- 7. Delete properties
        --
        -- The database foreign keys already cascade deletion
        -- to units, tenants, bookings, payments, chats,
        -- notifications, images, videos, etc.
        -- ====================================================

        delete from public.properties
        where id = any(property_ids);

    end if;

    -- ========================================================
    -- 8. Delete any subscriptions directly belonging to owner
    -- ========================================================

    if to_regclass('public.subscription_payments') is not null then
        delete from public.subscription_payments
        where owner_id = p_user_id;
    end if;

    if to_regclass('public.subscriptions') is not null then
        delete from public.subscriptions
        where owner_id = p_user_id;
    end if;

    -- ========================================================
    -- 9. Delete landlord records belonging exclusively to
    --    the deleted owner's properties.
    --
    -- IMPORTANT:
    -- If a landlord is still attached to another property,
    -- keep that landlord.
    -- ========================================================

    if array_length(landlord_ids, 1) is not null then

        delete from public.landlords l
        where l.id = any(landlord_ids)
          and not exists (
              select 1
              from public.properties p
              where p.landlord_id = l.id
          );

        get diagnostics deleted_landlord_count = row_count;
    end if;

    -- ========================================================
    -- 10. Delete orphaned tenant Auth accounts.
    --
    -- Their tenant rows were already removed through the
    -- property cascade.
    --
    -- Do not delete an Auth account if it is still referenced
    -- by another tenant record.
    -- ========================================================

    if array_length(tenant_auth_ids, 1) is not null then

        delete from auth.users u
        where u.id = any(tenant_auth_ids)
          and not exists (
              select 1
              from public.tenants t
              where t.auth_user_id = u.id
          )
          and u.id <> auth.uid();

        get diagnostics deleted_tenant_auth_count = row_count;
    end if;

    -- ========================================================
    -- 11. Delete orphaned landlord Auth accounts.
    --
    -- A landlord may be connected through either landlords.id
    -- or landlords.auth_user_id.
    --
    -- Do not delete an account that is still represented by
    -- another landlord record.
    -- ========================================================

    if array_length(landlord_auth_ids, 1) is not null then

        delete from auth.users u
        where u.id = any(landlord_auth_ids)
          and not exists (
              select 1
              from public.landlords l
              where l.id = u.id
                 or l.auth_user_id = u.id
          )
          and u.id <> auth.uid();

        get diagnostics deleted_landlord_auth_count = row_count;
    end if;

    -- ========================================================
    -- 12. Delete the owner's profile.
    --
    -- profiles.id references auth.users ON DELETE CASCADE.
    -- ========================================================

    delete from public.profiles
    where id = p_user_id;

    -- ========================================================
    -- 13. Delete the owner's actual Supabase Auth account.
    -- ========================================================

    delete from auth.users
    where id = p_user_id;

    -- ========================================================
    -- 14. Return operation summary
    -- ========================================================

    return jsonb_build_object(
        'success', true,
        'deleted_user_id', p_user_id,
        'deleted_properties', deleted_property_count,
        'deleted_landlords', deleted_landlord_count,
        'deleted_tenant_auth_accounts', deleted_tenant_auth_count,
        'deleted_landlord_auth_accounts', deleted_landlord_auth_count
    );

exception
    when others then
        raise exception 'JUMAA cascade deletion failed: %', SQLERRM;
end;
$$;

-- ============================================================
-- Lock down function execution.
-- ============================================================

revoke all
on function public.delete_jumaa_user(uuid)
from public;

grant execute
on function public.delete_jumaa_user(uuid)
to authenticated;
