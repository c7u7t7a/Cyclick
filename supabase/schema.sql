-- =============================================================================
-- CYCLICK — Supabase Schema
-- Run this entire file once in your Supabase SQL Editor:
--   https://supabase.com/dashboard → SQL Editor → New Query → paste → Run
-- =============================================================================

-- 1. Enable PostGIS for spatial/geographic data
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================================================
-- 2. PROFILES (extends Supabase Auth users)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL DEFAULT '',
  avatar_url        TEXT,
  bicycle_type      TEXT DEFAULT 'City',
  total_km          FLOAT NOT NULL DEFAULT 0,
  total_rides       INT   NOT NULL DEFAULT 0,
  total_co2_saved_grams FLOAT NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-create a profile row whenever a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- 3. REPORTS (Living Map — citizen-submitted hazards)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type         TEXT NOT NULL CHECK (type IN ('pothole', 'dangerousIntersection', 'blockedLane', 'safeZone')),
  -- PostGIS geography point (lon, lat, SRID 4326)
  geom         GEOGRAPHY(POINT, 4326) NOT NULL,
  reported_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reported_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  description  TEXT,
  upvote_count INT NOT NULL DEFAULT 0,
  is_active    BOOL NOT NULL DEFAULT true
);

-- Spatial index for fast proximity queries
CREATE INDEX IF NOT EXISTS reports_geom_idx ON public.reports USING GIST (geom);
-- Index to quickly filter active reports
CREATE INDEX IF NOT EXISTS reports_active_idx ON public.reports (is_active);

-- Helper view: return lat/lon as plain columns alongside geometry
CREATE OR REPLACE VIEW public.reports_view AS
  SELECT
    id,
    type,
    ST_Y(geom::geometry) AS latitude,
    ST_X(geom::geometry) AS longitude,
    reported_by,
    reported_at,
    description,
    upvote_count,
    is_active
  FROM public.reports;

-- =============================================================================
-- 4. RIDE HISTORY
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ride_history (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_at        TIMESTAMPTZ NOT NULL,
  finished_at       TIMESTAMPTZ NOT NULL,
  distance_km       FLOAT NOT NULL,
  duration_seconds  INT   NOT NULL,
  co2_saved_grams   FLOAT NOT NULL,
  safety_rating     FLOAT CHECK (safety_rating IS NULL OR safety_rating BETWEEN 1 AND 5),
  feedback_tags     TEXT[] DEFAULT '{}',
  city_hall_message TEXT,
  -- Optional: store the GPS route as a LineString for later analysis
  route             GEOGRAPHY(LINESTRING, 4326),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ride_history_user_idx ON public.ride_history (user_id);
CREATE INDEX IF NOT EXISTS ride_history_route_idx ON public.ride_history USING GIST (route);

-- After inserting a ride, update the user's aggregate stats
CREATE OR REPLACE FUNCTION public.update_profile_stats()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET
    total_km              = total_km + NEW.distance_km,
    total_rides           = total_rides + 1,
    total_co2_saved_grams = total_co2_saved_grams + NEW.co2_saved_grams,
    updated_at            = now()
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_ride_inserted ON public.ride_history;
CREATE TRIGGER on_ride_inserted
  AFTER INSERT ON public.ride_history
  FOR EACH ROW EXECUTE FUNCTION public.update_profile_stats();

-- =============================================================================
-- 5. COMMUNITY GROUPS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.community_groups (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  ride_date         TIMESTAMPTZ NOT NULL,
  meeting_point     TEXT NOT NULL,
  -- PostGIS point for the meeting location
  geom              GEOGRAPHY(POINT, 4326),
  participant_count INT NOT NULL DEFAULT 0,
  max_participants  INT NOT NULL DEFAULT 20,
  safety_level      TEXT NOT NULL DEFAULT 'medium' CHECK (safety_level IN ('low', 'medium', 'high')),
  organizer_id      UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  route_description TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS community_groups_geom_idx ON public.community_groups USING GIST (geom);

-- Junction table: who has joined each group
CREATE TABLE IF NOT EXISTS public.group_members (
  group_id   UUID NOT NULL REFERENCES public.community_groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- Auto-update participant_count when members join/leave
CREATE OR REPLACE FUNCTION public.sync_participant_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_groups
    SET participant_count = participant_count + 1
    WHERE id = NEW.group_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_groups
    SET participant_count = GREATEST(participant_count - 1, 0)
    WHERE id = OLD.group_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_member_change ON public.group_members;
CREATE TRIGGER on_member_change
  AFTER INSERT OR DELETE ON public.group_members
  FOR EACH ROW EXECUTE FUNCTION public.sync_participant_count();

-- =============================================================================
-- 6. ROW-LEVEL SECURITY (RLS)
-- Enable RLS on all tables so users can only see / edit their own data.
-- =============================================================================

-- profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view all profiles"  ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can view all profiles"   ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile"  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- reports (anyone can read active reports; only owner can insert/update)
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read active reports"          ON public.reports;
DROP POLICY IF EXISTS "Authenticated users can insert reports"  ON public.reports;
DROP POLICY IF EXISTS "Users can deactivate own reports"        ON public.reports;
CREATE POLICY "Anyone can read active reports" ON public.reports FOR SELECT USING (is_active = true);
CREATE POLICY "Authenticated users can insert reports"
  ON public.reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can deactivate own reports"
  ON public.reports FOR UPDATE USING (auth.uid() = reported_by);

-- ride_history (private — own rows only)
ALTER TABLE public.ride_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can see own rides"    ON public.ride_history;
DROP POLICY IF EXISTS "Users can insert own rides" ON public.ride_history;
DROP POLICY IF EXISTS "Users can update own rides" ON public.ride_history;
CREATE POLICY "Users can see own rides"
  ON public.ride_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own rides"
  ON public.ride_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own rides"
  ON public.ride_history FOR UPDATE USING (auth.uid() = user_id);

-- community_groups (public read, auth write)
ALTER TABLE public.community_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read groups"          ON public.community_groups;
DROP POLICY IF EXISTS "Authenticated can insert groups" ON public.community_groups;
DROP POLICY IF EXISTS "Organizer can update group"      ON public.community_groups;
CREATE POLICY "Anyone can read groups"     ON public.community_groups FOR SELECT USING (true);
CREATE POLICY "Authenticated can insert groups"
  ON public.community_groups FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Organizer can update group"
  ON public.community_groups FOR UPDATE USING (auth.uid() = organizer_id);

-- group_members
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read members" ON public.group_members;
DROP POLICY IF EXISTS "Users can join groups"   ON public.group_members;
DROP POLICY IF EXISTS "Users can leave groups"  ON public.group_members;
CREATE POLICY "Anyone can read members"    ON public.group_members FOR SELECT USING (true);
CREATE POLICY "Users can join groups"
  ON public.group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave groups"
  ON public.group_members FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 7. REALTIME — enable broadcast for Living Map
-- =============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_groups;

-- =============================================================================
-- Done! Your schema is ready.
-- Next steps in Flutter:
--   1. Copy your Project URL and anon key from:
--      https://supabase.com/dashboard → Settings → API
--   2. Paste them into lib/core/supabase_config.dart
-- =============================================================================
