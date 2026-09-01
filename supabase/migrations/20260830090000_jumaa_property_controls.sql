-- ============================================================
-- JUMAA OWNER PROPERTY CONTROLS
-- Property marking, warnings and suspension
-- ============================================================

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS is_suspended boolean
    NOT NULL DEFAULT false;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS marked_for_action boolean
    NOT NULL DEFAULT false;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS marked_reason text;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS marked_at timestamptz;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS marked_by uuid;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS suspended_by uuid;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS suspension_reason text;

ALTER TABLE public.properties
  ADD CONSTRAINT properties_marked_reason_check
  CHECK (
    marked_reason IS NULL
    OR marked_reason IN (
      'malfunction',
      'other',
      'subscription'
    )
  );

CREATE INDEX IF NOT EXISTS properties_suspended_idx
  ON public.properties(is_suspended);

CREATE INDEX IF NOT EXISTS properties_marked_idx
  ON public.properties(marked_for_action);

CREATE INDEX IF NOT EXISTS properties_marked_reason_idx
  ON public.properties(marked_reason);


COMMENT ON COLUMN public.properties.is_suspended
IS 'Whether JUMAA has suspended this property.';

COMMENT ON COLUMN public.properties.marked_for_action
IS 'Whether JUMAA has marked this property for action before suspension.';

COMMENT ON COLUMN public.properties.marked_reason
IS 'Reason the property has been marked: malfunction, other, or subscription.';

COMMENT ON COLUMN public.properties.suspension_reason
IS 'Reason associated with the property suspension.';

