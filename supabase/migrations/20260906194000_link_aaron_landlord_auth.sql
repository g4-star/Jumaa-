-- Link Aaron's landlord record to his Supabase Auth account
UPDATE public.landlords
SET
    auth_user_id = '2ef7ae9d-e5d5-4d3b-a7c7-81ec6361d562',
    updated_at = now()
WHERE id = '2ef7ae9d-e5d5-4d3b-a7c7-81ec6361d562'
  AND email = 'trippielv92@gmail.com';
