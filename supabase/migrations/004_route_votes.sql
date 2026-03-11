-- ============================================================
-- Migration 004: Route Votes (upvote / downvote like Reddit)
-- Run this in the Supabase SQL Editor
-- ============================================================

-- ── 1. Add downvotes column to community_routes ──────────────
ALTER TABLE public.community_routes
  ADD COLUMN IF NOT EXISTS downvotes INT DEFAULT 0;

-- ── 2. Route votes table (one row per user per route) ────────
CREATE TABLE IF NOT EXISTS public.route_votes (
  route_id  UUID REFERENCES public.community_routes(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  vote      SMALLINT NOT NULL CHECK (vote IN (1, -1)), -- 1=up, -1=down
  voted_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (route_id, user_id)
);

ALTER TABLE public.route_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "route_votes_read" ON public.route_votes;
CREATE POLICY "route_votes_read" ON public.route_votes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "route_votes_write" ON public.route_votes;
CREATE POLICY "route_votes_write" ON public.route_votes
  FOR ALL USING (auth.uid() = user_id);

-- ── 3. RPC: cast_route_vote ──────────────────────────────────
-- Upserts the vote, then recalculates likes/downvotes counts.
CREATE OR REPLACE FUNCTION public.cast_route_vote(rid UUID, v SMALLINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.route_votes (route_id, user_id, vote)
    VALUES (rid, auth.uid(), v)
  ON CONFLICT (route_id, user_id)
    DO UPDATE SET vote = EXCLUDED.vote, voted_at = now();

  UPDATE public.community_routes SET
    likes     = (SELECT COUNT(*) FROM public.route_votes WHERE route_id = rid AND vote =  1),
    downvotes = (SELECT COUNT(*) FROM public.route_votes WHERE route_id = rid AND vote = -1)
  WHERE id = rid;
END;
$$;

-- ── 4. View: top 3 routes per calendar month ─────────────────
CREATE OR REPLACE VIEW public.top_routes_by_month AS
SELECT
  date_trunc('month', cr.created_at) AS month,
  cr.id,
  cr.name,
  cr.author_name,
  cr.distance_km,
  cr.duration_minutes,
  cr.difficulty,
  cr.likes,
  cr.downvotes,
  (cr.likes - cr.downvotes) AS score,
  cr.created_at,
  RANK() OVER (
    PARTITION BY date_trunc('month', cr.created_at)
    ORDER BY (cr.likes - cr.downvotes) DESC
  ) AS rank
FROM public.community_routes cr;
