-- JUMAA subscription + Paystack billing foundation
-- Created: 2026-08-29

-- ============================================================
-- 1. SUBSCRIPTION PAYMENT STATUS
-- ============================================================

ALTER TABLE public.subscription_payments
  DROP CONSTRAINT IF EXISTS subscription_payments_status_check;

ALTER TABLE public.subscription_payments
  ADD CONSTRAINT subscription_payments_status_check
  CHECK (
    status IN (
      'pending',
      'processing',
      'success',
      'failed',
      'cancelled'
    )
  );


-- ============================================================
-- 2. SUBSCRIPTION STATUS
-- ============================================================

ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_status_check
  CHECK (
    status IN (
      'trial',
      'active',
      'expired',
      'cancelled'
    )
  );


-- ============================================================
-- 3. PREVENT DUPLICATE PAYSTACK REFERENCES
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS
  subscription_payments_reference_unique
ON public.subscription_payments (reference)
WHERE reference IS NOT NULL;


-- ============================================================
-- 4. LOOKUP INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS
  subscription_payments_owner_idx
ON public.subscription_payments (owner_id);

CREATE INDEX IF NOT EXISTS
  subscription_payments_property_idx
ON public.subscription_payments (property_id);

CREATE INDEX IF NOT EXISTS
  subscription_payments_subscription_idx
ON public.subscription_payments (subscription_id);

CREATE INDEX IF NOT EXISTS
  subscription_payments_status_idx
ON public.subscription_payments (status);

CREATE INDEX IF NOT EXISTS
  subscriptions_owner_idx
ON public.subscriptions (owner_id);

CREATE INDEX IF NOT EXISTS
  subscriptions_property_idx
ON public.subscriptions (property_id);

CREATE INDEX IF NOT EXISTS
  subscriptions_status_idx
ON public.subscriptions (status);


-- ============================================================
-- 5. BILLING TIER FUNCTION
-- ============================================================
-- Returns the monthly JUMAA subscription price based on
-- the number of units in a property.
--
-- 1-10   = 1,000
-- 11-20  = 2,000
-- 21-30  = 3,000
-- ...
-- 91-100 = 10,000
-- 101+   = 0 (custom plan)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_jumaa_monthly_rate(
  p_unit_count integer
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_unit_count IS NULL OR p_unit_count <= 0 THEN
    RETURN 0;
  END IF;

  IF p_unit_count <= 10 THEN
    RETURN 1000;
  ELSIF p_unit_count <= 20 THEN
    RETURN 2000;
  ELSIF p_unit_count <= 30 THEN
    RETURN 3000;
  ELSIF p_unit_count <= 40 THEN
    RETURN 4000;
  ELSIF p_unit_count <= 50 THEN
    RETURN 5000;
  ELSIF p_unit_count <= 60 THEN
    RETURN 6000;
  ELSIF p_unit_count <= 70 THEN
    RETURN 7000;
  ELSIF p_unit_count <= 80 THEN
    RETURN 8000;
  ELSIF p_unit_count <= 90 THEN
    RETURN 9000;
  ELSIF p_unit_count <= 100 THEN
    RETURN 10000;
  ELSE
    RETURN 0;
  END IF;
END;
$$;


-- ============================================================
-- 6. CALCULATE MONTHS COVERED
-- ============================================================
-- We only allow complete months.
--
-- Example:
-- monthly rate = 3,000
-- payment       = 9,000
-- months        = 3
--
-- If the amount is not an exact multiple, this returns 0.
-- The Edge Function will reject the payment.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_jumaa_months_covered(
  p_amount numeric,
  p_monthly_rate numeric
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_amount IS NULL
     OR p_monthly_rate IS NULL
     OR p_amount <= 0
     OR p_monthly_rate <= 0 THEN
    RETURN 0;
  END IF;

  IF MOD(p_amount, p_monthly_rate) <> 0 THEN
    RETURN 0;
  END IF;

  RETURN FLOOR(p_amount / p_monthly_rate)::integer;
END;
$$;


-- ============================================================
-- 7. COMMENTS
-- ============================================================

COMMENT ON FUNCTION public.get_jumaa_monthly_rate(integer)
IS 'Returns the JUMAA monthly subscription rate for a property unit count.';

COMMENT ON FUNCTION public.get_jumaa_months_covered(numeric, numeric)
IS 'Returns the number of complete subscription months represented by a payment amount.';
