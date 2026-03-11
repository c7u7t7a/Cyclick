-- ============================================================
-- Migration 007: Add missing meeting_lat / meeting_lon columns
-- to community_groups (safe to run multiple times)
-- Run this in the Supabase SQL Editor
-- ============================================================

ALTER TABLE public.community_groups
  ADD COLUMN IF NOT EXISTS meeting_lat  FLOAT,
  ADD COLUMN IF NOT EXISTS meeting_lon  FLOAT,
  ADD COLUMN IF NOT EXISTS route_description TEXT;
