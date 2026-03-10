// ─── Geography ────────────────────────────────────────────────────────────────
/// Geographic center of Sector 2, Bucharest (approximate).
const double kSector2Lat = 44.4557;
const double kSector2Lon = 26.1162;

const double kDefaultZoom = 14.0;
const double kNavigationZoom = 17.0;

// ─── Physics ──────────────────────────────────────────────────────────────────
/// Average car emits ~120 g CO₂ per km; cycling saves approximately that much.
const double kCo2GramsPerKm = 120.0;

// ─── App Strings ──────────────────────────────────────────────────────────────
const String kAppName = 'Cyclick';
const String kAppTagline = 'Pedaling Sector 2 Together';

// ─── Route Names (GoRouter) ───────────────────────────────────────────────────
const String kRouteAuth = '/auth';
const String kRouteHome = '/home';
const String kRouteFeedback = 'feedback'; // sub-route of /home

// ─── Map Tiles ────────────────────────────────────────────────────────────────
const String kOsmTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kOsmAttribution = '© OpenStreetMap contributors';

// ─── Supabase / PostGIS ───────────────────────────────────────────────────────
// TODO: Replace these placeholders with your real Supabase project credentials.
//
// Setup steps:
//   1. Create a Supabase project at https://supabase.com
//   2. Enable the PostGIS extension in the SQL editor:
//        CREATE EXTENSION IF NOT EXISTS postgis;
//   3. Create tables: users, reports, ride_history, community_groups
//      (see model files for column definitions)
//   4. Add supabase_flutter to pubspec.yaml
//   5. Initialize in main(): await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey)
//   6. Replace mock services with Supabase calls throughout the app.
const String kSupabaseUrl = 'https://lndtrkwsoizwnmauchtx.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxuZHRya3dzb2l6d25tYXVjaHR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDg3MzUsImV4cCI6MjA4ODcyNDczNX0.Y0WdSRseiNOEiHlsF1UafkJOpc0tuQ5NHTOVdk9XAY0';
