-- ============================================================
-- Migration 009: Ensure route_votes table exists
-- Run this in the Supabase SQL Editor if migration 004 was not executed.
-- The app now bypasses the cast_route_vote RPC and writes directly to this table.
-- ============================================================

-- 1. Add downvotes column (idempotent)
ALTER TABLE public.community_routes
  ADD COLUMN IF NOT EXISTS downvotes INT DEFAULT 0;

-- 2. Create route_votes table (idempotent)
CREATE TABLE IF NOT EXISTS public.route_votes (
  route_id  UUID REFERENCES public.community_routes(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  vote      SMALLINT NOT NULL CHECK (vote IN (1, -1)),
  voted_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (route_id, user_id)
);

ALTER TABLE public.route_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "route_votes_read"  ON public.route_votes;
CREATE POLICY "route_votes_read" ON public.route_votes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "route_votes_write" ON public.route_votes;
CREATE POLICY "route_votes_write" ON public.route_votes
  FOR ALL USING (auth.uid() = user_id);
