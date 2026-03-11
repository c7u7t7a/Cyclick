-- Admin helper: return all feedback from every user (bypasses RLS)
CREATE OR REPLACE FUNCTION get_all_feedback()
RETURNS TABLE (
  id          uuid,
  user_id     uuid,
  started_at  timestamptz,
  distance_km numeric,
  safety_rating numeric,
  feedback_tags text[],
  city_hall_message text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    id,
    user_id,
    started_at,
    distance_km,
    safety_rating,
    feedback_tags,
    city_hall_message
  FROM ride_history
  ORDER BY started_at DESC;
$$;
