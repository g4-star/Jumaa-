BEGIN;

ALTER TABLE public.properties
DROP CONSTRAINT IF EXISTS properties_owner_id_fkey;

ALTER TABLE public.properties
ADD CONSTRAINT properties_owner_id_fkey
FOREIGN KEY (owner_id)
REFERENCES public.profiles(id)
ON DELETE CASCADE;

COMMIT;
