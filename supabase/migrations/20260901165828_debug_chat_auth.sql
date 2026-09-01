-- Temporary diagnostic for JUMAA messaging RLS

CREATE OR REPLACE FUNCTION public.debug_chat_authorization(
  p_property_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_tenant_exists boolean;
  v_function_result boolean;
BEGIN
  v_auth_uid := auth.uid();

  SELECT EXISTS (
    SELECT 1
    FROM public.tenants t
    WHERE t.auth_user_id = v_auth_uid
      AND t.property_id = p_property_id
      AND lower(trim(coalesce(t.account_status, ''))) = 'active'
  )
  INTO v_tenant_exists;

  v_function_result :=
    public.can_access_property_for_messaging(
      p_property_id,
      v_auth_uid
    );

  RETURN jsonb_build_object(
    'auth_uid', v_auth_uid,
    'property_id', p_property_id,
    'tenant_exists', v_tenant_exists,
    'function_result', v_function_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.debug_chat_authorization(uuid)
TO authenticated;
