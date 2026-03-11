-- Grant admin status to a specific user by email.
-- Run this in the Supabase SQL Editor.

UPDATE public.profiles
SET is_admin = true
WHERE id = (
  SELECT id
  FROM auth.users
  WHERE email = 'lazarcristi720@gmail.com'
  LIMIT 1
);
