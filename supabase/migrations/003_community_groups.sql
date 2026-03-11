-- ============================================================
-- Migration 003: Community Groups + Join/Leave
-- Run this in the Supabase SQL Editor
-- ============================================================

-- ── 1. Community groups table ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_groups (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  description       TEXT,
  ride_date         TIMESTAMPTZ NOT NULL,
  meeting_point     TEXT,
  meeting_lat       FLOAT,
  meeting_lon       FLOAT,
  participant_count INT DEFAULT 0,
  max_participants  INT NOT NULL DEFAULT 20,
  safety_level      TEXT DEFAULT 'medium' CHECK (safety_level IN ('low','medium','high')),
  organizer_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  route_description TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.community_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_groups_read" ON public.community_groups;
CREATE POLICY "community_groups_read" ON public.community_groups
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "community_groups_insert" ON public.community_groups;
CREATE POLICY "community_groups_insert" ON public.community_groups
  FOR INSERT WITH CHECK (auth.uid() = organizer_id);

-- ── 2. Group members (join/leave) ────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_members (
  group_id  UUID REFERENCES public.community_groups(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "group_members_read" ON public.group_members;
CREATE POLICY "group_members_read" ON public.group_members
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "group_members_insert" ON public.group_members;
CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "group_members_delete" ON public.group_members;
CREATE POLICY "group_members_delete" ON public.group_members
  FOR DELETE USING (auth.uid() = user_id);

-- ── 3. RPCs: join / leave (atomically update participant_count) ─
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

-- ── 4. Enable Realtime ───────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_groups;

-- ── 5. Seed data ─────────────────────────────────────────────
INSERT INTO public.community_groups
  (name, description, ride_date, meeting_point, meeting_lat, meeting_lon,
   participant_count, max_participants, safety_level, route_description)
VALUES
  ('Sector 2 Morning Ride',
   'A calm morning loop through Parcul Circului — perfect for beginners!',
   NOW() + INTERVAL '1 day 6 hours',
   'Parcul Circului, Intrarea A', 44.4443, 26.1200, 8, 20, 'high',
   'Parcul Circului → Bd. Ferdinand → Parcul IOR'),
  ('Evening City Tour',
   'Explore Sector 2''s lit streets after sunset. Front & rear lights required!',
   NOW() + INTERVAL '18 hours',
   'Stația Metro Piața Muncii', 44.4260, 26.1180, 15, 25, 'medium',
   'Piața Muncii → Bd. Pache Protopopescu → Calea Moșilor'),
  ('Family Ride – Mogoșoaia',
   'Slow & family-friendly ride to Mogoșoaia Palace. Kids & e-bikes welcome!',
   NOW() + INTERVAL '3 days',
   'Piața Iancului', 44.4380, 26.1380, 6, 30, 'high',
   'Piața Iancului → Șos. Colentina → Mogoșoaia Palace'),
  ('Infrastructure Watch Ride',
   'Ride together to document cycling hazards for City Hall. Bring your phone!',
   NOW() + INTERVAL '5 days',
   'Stația Metro Universitate', 44.4355, 26.1016, 22, 50, 'low',
   'Universitate → Bd. Magheru → Calea Moșilor → Piața Muncii')
ON CONFLICT DO NOTHING;
