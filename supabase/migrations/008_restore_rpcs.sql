-- ============================================================
-- Migration 008: Restore join_group / leave_group RPCs
-- Run this in the Supabase SQL Editor if you see PGRST202
-- errors about join_group / leave_group not found.
-- ============================================================

CREATE OR REPLACE FUNCTION public.join_group(gid UUID)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO public.group_members (group_id, user_id)
    VALUES (gid, auth.uid()) ON CONFLICT DO NOTHING;
  UPDATE public.community_groups
    SET participant_count = (
      SELECT COUNT(*) FROM public.group_members WHERE group_id = gid
    )
    WHERE id = gid;
$$;

CREATE OR REPLACE FUNCTION public.leave_group(gid UUID)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.group_members
    WHERE group_id = gid AND user_id = auth.uid();
  UPDATE public.community_groups
    SET participant_count = (
      SELECT COUNT(*) FROM public.group_members WHERE group_id = gid
    )
    WHERE id = gid;
$$;
