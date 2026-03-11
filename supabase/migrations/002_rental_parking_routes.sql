-- ============================================================
-- Migration 002: Rentals, Parking, Community Routes & Admin
-- Run this in the Supabase SQL Editor after schema.sql
-- ============================================================

-- ── 1. Admin flag on profiles ────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOL DEFAULT false;

-- ── 2. Rental stations ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rental_stations (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  latitude       FLOAT NOT NULL,
  longitude      FLOAT NOT NULL,
  available_bikes INT DEFAULT 0,
  total_docks    INT DEFAULT 10,
  is_active      BOOL DEFAULT true,
  created_at     TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.rental_stations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rental_stations_read" ON public.rental_stations;
CREATE POLICY "rental_stations_read" ON public.rental_stations
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "rental_stations_admin_write" ON public.rental_stations;
CREATE POLICY "rental_stations_admin_write" ON public.rental_stations
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ── 3. Bike parkings ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bike_parkings (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  latitude   FLOAT NOT NULL,
  longitude  FLOAT NOT NULL,
  capacity   INT DEFAULT 10,
  is_covered BOOL DEFAULT false,
  is_active  BOOL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.bike_parkings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bike_parkings_read" ON public.bike_parkings;
CREATE POLICY "bike_parkings_read" ON public.bike_parkings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "bike_parkings_admin_write" ON public.bike_parkings;
CREATE POLICY "bike_parkings_admin_write" ON public.bike_parkings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ── 4. Community routes ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_routes (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  author_id        UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  author_name      TEXT,
  waypoints        JSONB NOT NULL DEFAULT '[]',
  distance_km      FLOAT DEFAULT 0,
  duration_minutes INT DEFAULT 0,
  difficulty       TEXT DEFAULT 'medium' CHECK (difficulty IN ('easy','medium','hard')),
  likes            INT DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.community_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_routes_read" ON public.community_routes;
CREATE POLICY "community_routes_read" ON public.community_routes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "community_routes_insert" ON public.community_routes;
CREATE POLICY "community_routes_insert" ON public.community_routes
  FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "community_routes_delete_own" ON public.community_routes;
CREATE POLICY "community_routes_delete_own" ON public.community_routes
  FOR DELETE USING (auth.uid() = author_id);

-- ── 5. RPC: increment route likes ───────────────────────────
CREATE OR REPLACE FUNCTION public.increment_route_likes(rid UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.community_routes
  SET likes = likes + 1
  WHERE id = rid;
$$;

-- ── 6. Seed data: rental stations (Sector 2, Bucharest) ────
INSERT INTO public.rental_stations (name, latitude, longitude, available_bikes, total_docks)
VALUES
  ('Piața Obor',     44.4557, 26.1162, 5, 12),
  ('Parcul Tei',     44.4700, 26.1050, 3,  8),
  ('Bd. Ferdinand',  44.4480, 26.1210, 7, 15)
ON CONFLICT DO NOTHING;

-- ── 7. Seed data: bike parkings ─────────────────────────────
INSERT INTO public.bike_parkings (name, latitude, longitude, capacity, is_covered)
VALUES
  ('Colțea Hospital',    44.4320, 26.1030, 20, true),
  ('Piața Muncii',       44.4240, 26.1290, 15, false),
  ('Parcul IOR',         44.4097, 26.1600, 30, false)
ON CONFLICT DO NOTHING;

-- ── 8. Realtime for rental availability ─────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_stations;
