-- ============================================================
-- Migration 010: Achievements + Friends
-- Run this in the Supabase SQL Editor
-- ============================================================

-- ── 1. Achievement catalog (static definitions) ──────────────
CREATE TABLE IF NOT EXISTS public.achievements_catalog (
  id             TEXT PRIMARY KEY,
  title_en       TEXT NOT NULL,
  title_ro       TEXT NOT NULL,
  description_en TEXT NOT NULL,
  description_ro TEXT NOT NULL,
  icon_emoji     TEXT NOT NULL,
  tier           TEXT NOT NULL DEFAULT 'bronze'
                   CHECK (tier IN ('bronze','silver','gold','platinum')),
  category       TEXT NOT NULL DEFAULT 'riding'
                   CHECK (category IN ('riding','eco','social','safety','civic'))
);

-- Seed all achievements (idempotent)
INSERT INTO public.achievements_catalog
  (id, title_en, title_ro, description_en, description_ro, icon_emoji, tier, category)
VALUES
  ('first_ride',        'First Pedal',     'Prima Pedalare',   'Complete your first ride',        'Finalizează prima ta cursă',         '🚴', 'bronze',   'riding'),
  ('five_rides',        'High Five',       'Cinci Curse',      'Complete 5 rides',                'Finalizează 5 curse',                '🤙', 'bronze',   'riding'),
  ('ten_rides',         'Perfect Ten',     'Zece la Rând',     'Complete 10 rides',               'Finalizează 10 curse',               '💪', 'silver',   'riding'),
  ('twenty_five_rides', 'Velodrome',       'Velodrom',         'Complete 25 rides',               'Finalizează 25 de curse',            '⭐', 'silver',   'riding'),
  ('century_rides',     'Century Club',    'Centurion',        'Complete 100 rides',              'Finalizează 100 de curse',           '🏆', 'gold',     'riding'),
  ('ten_km',            '10 km Wanderer',  '10 km Explorator', 'Cycle a total of 10 km',          'Pedalează 10 km total',              '📍', 'bronze',   'riding'),
  ('fifty_km',          '50 km Explorer',  '50 km Explorator', 'Cycle a total of 50 km',          'Pedalează 50 km total',              '🗺️', 'silver',  'riding'),
  ('hundred_km',        'Century Rider',   'Ciclist de Secol', 'Cycle a total of 100 km',         'Pedalează 100 km total',             '🚀', 'gold',     'riding'),
  ('five_hundred_km',   'Iron Cyclist',    'Ciclist de Fier',  'Cycle a total of 500 km',         'Pedalează 500 km total',             '🏅', 'platinum', 'riding'),
  ('eco_starter',       'Eco Starter',     'Eco-Inceput',      'Save 500 g of CO₂',               'Economisește 500 g de CO₂',          '🌱', 'bronze',   'eco'),
  ('eco_warrior',       'Eco Warrior',     'Luptător Eco',     'Save 1 kg of CO₂',               'Economisește 1 kg de CO₂',           '🌿', 'silver',   'eco'),
  ('eco_hero',          'Green Hero',      'Erou Verde',       'Save 5 kg of CO₂',               'Economisește 5 kg de CO₂',           '🌍', 'gold',     'eco'),
  ('safety_star',       'Safety Star',     'Steaua Siguranței','Rate 5 rides with 4+ stars',      'Evaluează 5 curse cu 4+ stele',      '⛑️', 'silver',  'safety'),
  ('first_friend',      'Social Cyclist',  'Ciclist Social',   'Add your first friend',           'Adaugă primul prieten',              '🤝', 'bronze',   'social'),
  ('community_joiner',  'Community Spirit','Spirit Comunitar',  'Join a community group',         'Alătură-te unui grup comunitar',     '👥', 'bronze',   'social'),
  ('civic_voice',       'Civic Voice',     'Voce Civică',      'Submit 3 city hall reports',      'Trimite 3 sesizări la primărie',     '📢', 'bronze',   'civic')
ON CONFLICT (id) DO NOTHING;

-- ── 2. User achievements (unlocked per user) ─────────────────
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  achievement_id TEXT REFERENCES public.achievements_catalog(id) ON DELETE CASCADE NOT NULL,
  unlocked_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, achievement_id)
);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ach_select" ON public.user_achievements;
CREATE POLICY "ach_select" ON public.user_achievements
  FOR SELECT USING (true); -- public (friends can see each other's achievements)

DROP POLICY IF EXISTS "ach_insert" ON public.user_achievements;
CREATE POLICY "ach_insert" ON public.user_achievements
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ach_delete" ON public.user_achievements;
CREATE POLICY "ach_delete" ON public.user_achievements
  FOR DELETE USING (auth.uid() = user_id);

-- ── 3. Friendships ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.friendships (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  addressee_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (requester_id, addressee_id)
);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friends_select" ON public.friendships;
CREATE POLICY "friends_select" ON public.friendships
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS "friends_insert" ON public.friendships;
CREATE POLICY "friends_insert" ON public.friendships
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "friends_update" ON public.friendships;
CREATE POLICY "friends_update" ON public.friendships
  FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS "friends_delete" ON public.friendships;
CREATE POLICY "friends_delete" ON public.friendships
  FOR DELETE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ── 4. Denormalised stats on profiles ────────────────────────
-- These are kept up to date by the app after each ride is saved.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS total_km              FLOAT   DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_rides           INT     DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_co2_saved_grams FLOAT   DEFAULT 0;

-- Allow anyone to read profiles (needed for friend search + public profiles)
DROP POLICY IF EXISTS "profiles_read" ON public.profiles;
CREATE POLICY "profiles_read" ON public.profiles
  FOR SELECT USING (true);

-- Users can update their own profile
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ── 5. Index for name search ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_name_lower
  ON public.profiles (lower(name));
