-- Grant admin status to a specific user by email.
-- Run this in the Supabase SQL Editor.

-- 1. Set is_admin=true if the profile row already exists
UPDATE public.profiles
SET is_admin = true
WHERE id = (
  SELECT id
  FROM auth.users
  WHERE email = 'lazarcristi720@gmail.com'
  LIMIT 1
);

-- 2. Trigger: auto-promote admin emails on profile creation
CREATE OR REPLACE FUNCTION public.promote_admin_on_signup()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.email = 'lazarcristi720@gmail.com' THEN
    NEW.is_admin := true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promote_admin ON public.profiles;
CREATE TRIGGER trg_promote_admin
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.promote_admin_on_signup();
