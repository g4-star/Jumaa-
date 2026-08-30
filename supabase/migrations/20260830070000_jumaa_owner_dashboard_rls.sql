-- ============================================================
-- JUMAA OWNER DASHBOARD RLS
-- Allow authenticated JUMAA owners to read platform data.
-- ============================================================

-- Helper function.
-- SECURITY DEFINER allows this function to check profiles
-- without getting trapped by the profiles table's own RLS.
create or replace function public.is_jumaa_owner()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and lower(coalesce(role, '')) = 'jumaa_owner'
  );
$$;

revoke all on function public.is_jumaa_owner() from public;
grant execute on function public.is_jumaa_owner() to authenticated;


-- ============================================================
-- PROFILES
-- ============================================================

drop policy if exists "jumaa_owner_view_all_profiles" on public.profiles;

create policy "jumaa_owner_view_all_profiles"
on public.profiles
for select
to authenticated
using (
  public.is_jumaa_owner()
  or id = auth.uid()
);


-- ============================================================
-- PROPERTIES
-- ============================================================

drop policy if exists "jumaa_owner_view_all_properties" on public.properties;

create policy "jumaa_owner_view_all_properties"
on public.properties
for select
to authenticated
using (
  public.is_jumaa_owner()
  or owner_id = auth.uid()
  or landlord_id = auth.uid()
);


-- ============================================================
-- UNITS
-- ============================================================

drop policy if exists "jumaa_owner_view_all_units" on public.units;

create policy "jumaa_owner_view_all_units"
on public.units
for select
to authenticated
using (
  public.is_jumaa_owner()
  or exists (
    select 1
    from public.properties p
    where p.id = units.property_id
      and (
        p.owner_id = auth.uid()
        or p.landlord_id = auth.uid()
      )
  )
);


-- ============================================================
-- SUBSCRIPTION PAYMENTS
-- ============================================================

drop policy if exists "jumaa_owner_view_subscription_payments"
on public.subscription_payments;

create policy "jumaa_owner_view_subscription_payments"
on public.subscription_payments
for select
to authenticated
using (
  public.is_jumaa_owner()
  or owner_id = auth.uid()
);
