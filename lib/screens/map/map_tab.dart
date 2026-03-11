import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../widgets/weather_banner.dart';
import 'active_ride_card.dart';
import 'report_bottom_sheet.dart';

/// Full-screen map tab — the core of Cyclick.
/// Shows OpenStreetMap tiles, citizen reports, and the floating search bar.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider).valueOrNull ?? const [];
    final currentPos = ref.watch(currentPositionProvider);
    final destination = ref.watch(navigationDestinationProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(kSector2Lat, kSector2Lon),
              initialZoom: kDefaultZoom,
              onTap: (tapPos, latlng) => _onMapTap(latlng),
            ),
            children: [
              // OSM base tiles
              TileLayer(
                urlTemplate: kOsmTileUrl,
                userAgentPackageName: 'com.cyclick.app',
              ),
              // Report markers (Living Map)
              MarkerLayer(markers: _buildReportMarkers(reports)),
              // Current user position
              if (currentPos != null)
                MarkerLayer(markers: [_buildUserMarker(currentPos)]),
              // Destination pin
              if (destination != null)
                MarkerLayer(markers: [_buildDestinationMarker(destination)]),
            ],
          ),

          // ── Floating Search Bar + Weather ────────────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchBar(
                    controller: _searchCtrl,
                    onDestinationSet: (latlng) {
                      ref.read(navigationDestinationProvider.notifier).state =
                          latlng;
                    },
                  ),
                  const SizedBox(height: 6),
                  const WeatherBanner(),
                ],
              ),
            ),
          ),

          // ── Active Ride Bottom Card ──────────────────────────────────────────
          if (destination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ActiveRideCard(
                destination: destination,
                onFinish: _finishRide,
              ),
            ),

          // ── Locate Me Button ─────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: destination != null ? 200 : 100,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.primary,
              elevation: 4,
              onPressed: _locateMe,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      // ── Report FAB ──────────────────────────────────────────────────────────
      floatingActionButton: destination == null
          ? FloatingActionButton.extended(
              heroTag: 'report',
              onPressed: () => _showReportSheet(),
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text(
                'Report',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _onMapTap(LatLng latlng) {
    // Long-press / tap to set destination when no ride is active.
    if (!ref.read(rideProvider).isActive) {
      ref.read(navigationDestinationProvider.notifier).state = latlng;
    }
  }

  Future<void> _locateMe() async {
    final locService = ref.read(locationServiceProvider);
    final pos = await locService.getCurrentPosition();
    if (pos != null && mounted) {
      final latlng = LatLng(pos.latitude, pos.longitude);
      ref.read(currentPositionProvider.notifier).state = latlng;
      _mapController.move(latlng, kNavigationZoom);
    }
  }

  void _finishRide() {
    final user = ref.read(authStateProvider).valueOrNull?.user;
    if (user == null) return;

    final completed = ref.read(rideProvider.notifier).finishRide(user.id);
    ref.read(navigationDestinationProvider.notifier).state = null;

    if (mounted) {
      context.go('/home/feedback', extra: completed);
    }
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(
        onReportSubmit: (type) async {
          final pos = ref.read(currentPositionProvider);
          final userId =
              ref.read(authStateProvider).valueOrNull?.user?.id ?? '';
          if (pos != null) {
            // Insert into Supabase; Realtime stream will update the map.
            await Supabase.instance.client.from('reports').insert({
              'type': type.name,
              'geom': 'SRID=4326;POINT(${pos.longitude} ${pos.latitude})',
              'reported_by': userId.isNotEmpty ? userId : null,
              'description': null,
            });
          }
        },
      ),
    );
  }

  List<Marker> _buildReportMarkers(List<ReportModel> reports) {
    return reports
        .map(
          (r) => Marker(
            point: LatLng(r.latitude, r.longitude),
            width: 40,
            height: 40,
            child: Tooltip(
              message: r.type.label.replaceAll('\n', ' '),
              child: Container(
                decoration: BoxDecoration(
                  color: r.type.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: r.type.color.withAlpha(120),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(r.type.icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        )
        .toList();
  }

  Marker _buildUserMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(100),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(
          Icons.directions_bike_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Marker _buildDestinationMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 44,
      height: 44,
      child: const Icon(
        Icons.location_pin,
        color: Colors.red,
        size: 44,
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(LatLng) onDestinationSet;

  const _SearchBar({
    required this.controller,
    required this.onDestinationSet,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search in Sector 2…',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => controller.clear(),
                )
              : const Icon(Icons.mic_rounded, color: AppTheme.subtleText),
          border: InputBorder.none,
          filled: true,
          fillColor: AppTheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            borderSide:
                const BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (query) {
          // TODO: Integrate a geocoding API (e.g., OpenStreetMap Nominatim or
          // Supabase Edge Function wrapping Google Maps Geocoding) to resolve
          // address strings into LatLng coordinates.
          //
          // For now, mock a central Sector 2 destination.
          onDestinationSet(const LatLng(kSector2Lat + 0.01, kSector2Lon + 0.01));
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
