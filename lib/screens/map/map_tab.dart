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
import '../../providers/rental_provider.dart';
import '../../providers/parking_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/routing_service.dart';
import '../../widgets/weather_banner.dart';
import 'active_ride_card.dart';
import 'report_bottom_sheet.dart';

enum _MapMode { navigate, rent }

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

  _MapMode? _mapMode;
  RentalStation? _selectedStation;
  List<LatLng> _walkingRoute = [];
  int _walkingMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapMode == null) _showModePicker(initial: true);
    });
  }

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
    final rentals =
        ref.watch(rentalProvider).valueOrNull ?? const <RentalStation>[];
    final parkings =
        ref.watch(parkingProvider).valueOrNull ?? const <BikeParking>[];
    final isRo = ref.watch(isRomanianProvider);
    final isRent = _mapMode == _MapMode.rent;
    final isNavigate = _mapMode == _MapMode.navigate;

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
              TileLayer(
                urlTemplate: kOsmTileUrl,
                userAgentPackageName: 'com.cyclick.app',
              ),
              if (isNavigate) ...[
                MarkerLayer(markers: _buildReportMarkers(reports)),
                if (destination != null)
                  MarkerLayer(
                      markers: [_buildDestinationMarker(destination)]),
              ],
              if (isRent) ...[
                if (_walkingRoute.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _walkingRoute,
                      color: AppTheme.primary,
                      strokeWidth: 4,
                      isDotted: true,
                    ),
                  ]),
                MarkerLayer(
                  markers: rentals.map((s) {
                    final isSel = _selectedStation?.id == s.id;
                    return Marker(
                      point: s.latLng,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _selectStation(s),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.primary
                                : const Color(0xFF1565C0),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white,
                                width: isSel ? 3 : 2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26, blurRadius: 6)
                            ],
                          ),
                          child: const Icon(Icons.pedal_bike_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: parkings
                      .map((p) => Marker(
                            point: p.latLng,
                            width: 36,
                            height: 36,
                            child: Tooltip(
                              message:
                                  '${p.name} (${p.capacity} spots${p.isCovered ? ', covered' : ''})',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A1B9A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(
                                    Icons.local_parking_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              if (currentPos != null)
                MarkerLayer(markers: [_buildUserMarker(currentPos)]),
            ],
          ),

          // ── Search Bar + Weather ─────────────────────────────────────────────
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
                      if (isNavigate) {
                        ref
                            .read(navigationDestinationProvider.notifier)
                            .state = latlng;
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  const WeatherBanner(),
                ],
              ),
            ),
          ),

          // ── Mode toggle chip ─────────────────────────────────────────────────
          if (_mapMode != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              right: 16,
              child: _ModeChip(
                mode: _mapMode!,
                isRo: isRo,
                onTap: _showModePicker,
              ),
            ),

          // ── Navigate: Active Ride Card ───────────────────────────────────────
          if (isNavigate && destination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ActiveRideCard(
                  destination: destination, onFinish: _finishRide),
            ),

          // ── Rent: Station Card ───────────────────────────────────────────────
          if (isRent && _selectedStation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StationCard(
                station: _selectedStation!,
                walkingMinutes: _walkingMinutes,
                isRo: isRo,
                onClose: () => setState(() {
                  _selectedStation = null;
                  _walkingRoute = [];
                }),
              ),
            ),

          // ── Rent: Legend ─────────────────────────────────────────────────────
          if (isRent)
            Positioned(
              bottom: _selectedStation != null ? 180 : 24,
              left: 16,
              child: Row(
                children: [
                  _LegendChip(
                    color: const Color(0xFF1565C0),
                    icon: Icons.pedal_bike_rounded,
                    label: isRo ? 'Închiriere' : 'Rental',
                  ),
                  const SizedBox(width: 8),
                  _LegendChip(
                    color: const Color(0xFF6A1B9A),
                    icon: Icons.local_parking_rounded,
                    label: isRo ? 'Parcare' : 'Parking',
                  ),
                ],
              ),
            ),

          // ── Locate Me ────────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: (isNavigate && destination != null) ? 200 : 100,
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
      // ── Navigate: Report FAB ──────────────────────────────────────────────────
      floatingActionButton: (isNavigate && destination == null)
          ? FloatingActionButton.extended(
              heroTag: 'report',
              onPressed: _showReportSheet,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Report',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _onMapTap(LatLng latlng) {
    if (_mapMode == _MapMode.navigate && !ref.read(rideProvider).isActive) {
      ref.read(navigationDestinationProvider.notifier).state = latlng;
    }
  }

  void _showModePicker({bool initial = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !initial,
      enableDrag: !initial,
      builder: (_) => _ModePickerSheet(
        onNavigate: () {
          setState(() => _mapMode = _MapMode.navigate);
          Navigator.pop(context);
        },
        onRent: () {
          setState(() => _mapMode = _MapMode.rent);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _selectStation(RentalStation station) async {
    final pos = ref.read(currentPositionProvider);
    setState(() {
      _selectedStation = station;
      _walkingRoute = [];
      _walkingMinutes = 0;
    });
    if (pos != null) {
      final svc = RoutingService();
      final route = await svc.getWalkingPolyline(pos, station.latLng);
      final mins = await svc.getWalkingMinutes(pos, station.latLng);
      if (mounted) {
        setState(() {
          _walkingRoute = route;
          _walkingMinutes = mins;
        });
      }
    }
    _mapController.move(station.latLng, 15.5);
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
// ─── Mode Picker Sheet ──────────────────────────────────────────────────────────────
class _ModePickerSheet extends StatelessWidget {
  final VoidCallback onNavigate;
  final VoidCallback onRent;
  const _ModePickerSheet(
      {required this.onNavigate, required this.onRent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How are you riding today?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your mode to see relevant info on the map.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.directions_bike_rounded,
                  color: AppTheme.primary,
                  title: 'I have my bike',
                  subtitle: 'Navigate & report hazards',
                  onTap: onNavigate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ModeCard(
                  icon: Icons.store_mall_directory_rounded,
                  color: const Color(0xFF1565C0),
                  title: 'I want to rent',
                  subtitle: 'Find rental stations & parking',
                  onTap: onRent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mode Toggle Chip ──────────────────────────────────────────────────────────────
class _ModeChip extends StatelessWidget {
  final _MapMode mode;
  final bool isRo;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.mode, required this.isRo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRent = mode == _MapMode.rent;
    final color =
        isRent ? const Color(0xFF1565C0) : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6)
          ],
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRent
                  ? Icons.store_mall_directory_rounded
                  : Icons.directions_bike_rounded,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isRent
                  ? (isRo ? 'Rentă' : 'Rent')
                  : (isRo ? 'Navighez' : 'Navigate'),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Station Card (rent mode overlay) ──────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final RentalStation station;
  final int walkingMinutes;
  final bool isRo;
  final VoidCallback onClose;
  const _StationCard({
    required this.station,
    required this.walkingMinutes,
    required this.isRo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pedal_bike_rounded,
                  color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(station.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                icon: Icons.directions_bike_rounded,
                label: isRo
                    ? '${station.availableBikes} biciclete'
                    : '${station.availableBikes} bikes',
                color: station.availableBikes > 0
                    ? AppTheme.primary
                    : Colors.red,
              ),
              _StatPill(
                icon: Icons.dock_rounded,
                label: '${station.totalDocks} docks',
                color: Colors.grey,
              ),
              if (walkingMinutes > 0)
                _StatPill(
                  icon: Icons.directions_walk_rounded,
                  label: isRo
                      ? '$walkingMinutes min pe jos'
                      : '$walkingMinutes min walk',
                  color: const Color(0xFF1565C0),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      );
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendChip(
      {required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      );
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
