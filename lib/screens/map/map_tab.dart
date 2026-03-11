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
import '../../providers/cycling_routes_layer_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/notification_service.dart';
import '../../services/routing_service.dart';
import '../../widgets/weather_banner.dart';
import '../../core/mapbox_token.dart';
import 'active_ride_card.dart';
import 'report_bottom_sheet.dart';

// ─── Cycling Route Alternative model ─────────────────────────────────────────
class _CyclingRoute {
  final String label;
  final String summary;
  final List<LatLng> points;
  final Color color;
  final IconData icon;
  const _CyclingRoute({
    required this.label,
    required this.summary,
    required this.points,
    required this.color,
    required this.icon,
  });
}

enum _MapMode { navigate, rent }

/// Which point the next map-tap will set in navigate mode.
enum _PickStep { none, pickingOrigin, pickingDest }

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
  _PickStep _pickStep = _PickStep.none;
  RentalStation? _selectedStation;
  List<LatLng> _walkingRoute = [];
  int _walkingMinutes = 0;
  CyclingRouteFeature? _selectedRoute;

  // Three route alternatives (safe / balanced / fast)
  List<_CyclingRoute> _routeOptions = [];
  int _selectedRouteIdx = 1; // default: balanced
  bool _loadingRoutes = false;

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
    final origin = ref.watch(rideOriginProvider);
    final destination = ref.watch(navigationDestinationProvider);
    final rentals =
        ref.watch(rentalProvider).valueOrNull ?? const <RentalStation>[];
    final parkings =
        ref.watch(parkingProvider).valueOrNull ?? const <BikeParking>[];
    final isRo = ref.watch(isRomanianProvider);
    final isRent = _mapMode == _MapMode.rent;
    final isNavigate = _mapMode == _MapMode.navigate;
    final routes =
        ref.watch(cyclingRoutesProvider).valueOrNull ?? const [];
    final showRoutes = ref.watch(showCyclingRoutesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          Builder(builder: (context) {
            final isActive = ref.watch(rideProvider).isActive;
            Widget mapWidget = FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(kSector2Lat, kSector2Lon),
              initialZoom: kDefaultZoom,
              onTap: (tapPos, latlng) => _onMapTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    '$kMapboxStyleUrl?access_token=$kMapboxPublicToken',
                userAgentPackageName: 'com.cyclick.app',
                tileProvider: NetworkTileProvider(),
              ),
              // ── Cycling infrastructure risk layer (always under markers) ────
              if (showRoutes && routes.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final f in routes)
                      for (final seg in f.segments)
                        if (seg.length >= 2)
                          Polyline(
                            points: seg,
                            color: f.color.withAlpha(204),
                            strokeWidth: 4,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                  ],
                ),
              if (isNavigate) ...[
                // ── 3 route alternatives polylines ─────────────────────────
                if (_routeOptions.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (int i = 0; i < _routeOptions.length; i++)
                        if (_routeOptions[i].points.length >= 2)
                          Polyline(
                            points: _routeOptions[i].points,
                            color: i == _selectedRouteIdx
                                ? _routeOptions[i].color
                                : _routeOptions[i].color.withAlpha(80),
                            strokeWidth: i == _selectedRouteIdx ? 5 : 3,
                            isDotted: i != _selectedRouteIdx,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                    ],
                  ),
                MarkerLayer(markers: _buildReportMarkers(reports)),
                MarkerLayer(
                  markers: parkings
                      .map((p) => Marker(
                            point: p.latLng,
                            width: 48,
                            height: 48,
                            child: Tooltip(
                              message:
                                  '${p.name}\n${p.capacity} ${isRo ? 'locuri' : 'spots'}${p.isCovered ? (isRo ? ' · acoperit' : ' · covered') : ''}',
                              preferBelow: false,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A1B9A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 8,
                                        offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Icon(
                                    Icons.local_parking_rounded,
                                    color: Colors.white,
                                    size: 24),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                if (origin != null)
                  MarkerLayer(markers: [_buildOriginMarker(origin)]),
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
          );
            // Apply 3D perspective tilt during active navigation
            if (isActive && isNavigate) {
              mapWidget = ClipRect(
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0008)
                    ..rotateX(0.35),
                  alignment: Alignment.bottomCenter,
                  child: mapWidget,
                ),
              );
            }
            return mapWidget;
          }),

          // ── Search / Navigation Panel + Mode/Music controls ─────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ref.watch(rideProvider).isActive
                              ? _ActiveDrivingBar(isRo: isRo)
                              : (isNavigate
                                  ? _NavigationSearchPanel(
                                      origin: origin,
                                      destination: destination,
                                      pickStep: _pickStep,
                                      isRo: isRo,
                                      currentPos: currentPos,
                                      onOriginSet: (latlng) {
                                        ref
                                            .read(rideOriginProvider.notifier)
                                            .state = latlng;
                                        setState(
                                            () => _pickStep = _PickStep.none);
                                        _maybeFetchRoutes(latlng,
                                            ref.read(navigationDestinationProvider));
                                      },
                                      onDestinationSet: (latlng) {
                                        ref
                                            .read(navigationDestinationProvider
                                                .notifier)
                                            .state = latlng;
                                        setState(
                                            () => _pickStep = _PickStep.none);
                                        _maybeFetchRoutes(
                                            ref.read(rideOriginProvider),
                                            latlng);
                                      },
                                      onPickOriginFromMap: () => setState(() =>
                                          _pickStep = _PickStep.pickingOrigin),
                                      onPickDestFromMap: () => setState(
                                          () =>
                                              _pickStep = _PickStep.pickingDest),
                                      onClearOrigin: () {
                                        ref
                                            .read(rideOriginProvider.notifier)
                                            .state = null;
                                        setState(() {
                                          _pickStep = _PickStep.none;
                                          _routeOptions = [];
                                        });
                                      },
                                      onClearDest: () {
                                        ref
                                            .read(navigationDestinationProvider
                                                .notifier)
                                            .state = null;
                                        setState(() {
                                          _pickStep = _PickStep.none;
                                          _routeOptions = [];
                                        });
                                      },
                                    )
                                  : _SearchBar(
                                      controller: _searchCtrl,
                                      onDestinationSet: (latlng) {
                                        if (isNavigate) {
                                          ref
                                              .read(navigationDestinationProvider
                                                  .notifier)
                                              .state = latlng;
                                          _maybeFetchRoutes(
                                              ref.read(rideOriginProvider),
                                              latlng);
                                        }
                                      },
                                    )),
                        ),
                        if (_mapMode != null) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _ModeChip(
                                mode: _mapMode!,
                                isRo: isRo,
                                onTap: _showModePicker,
                              ),
                              const SizedBox(height: 6),
                              _MusicToggleButton(
                                onTap: () => _showMusicSheet(context),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    const WeatherBanner(),
                  ],
                ),
              ),
            ),
          ),

          // ── Navigate: Route Options Panel ────────────────────────────────
          if (isNavigate && origin != null && destination != null &&
              !ref.watch(rideProvider).isActive)
            Positioned(
              bottom: 180,
              left: 12,
              right: 12,
              child: _RouteOptionsPanel(
                routes: _routeOptions,
                loading: _loadingRoutes,
                selectedIdx: _selectedRouteIdx,
                isRo: isRo,
                onSelect: (i) => setState(() => _selectedRouteIdx = i),
              ),
            ),

          // ── Navigate: Active Ride Card ───────────────────────────────────────
          if (isNavigate && origin != null && destination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ActiveRideCard(
                  origin: origin,
                  destination: destination,
                  onFinish: _finishRide),
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

          // ── Legend (+ risk layer toggle) ────────────────────────────────────
          if (isNavigate || isRent)
            Positioned(
              bottom: _selectedRoute != null
                  ? 188
                  : (isRent && _selectedStation != null)
                      ? 180
                      : 24,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Risk map toggle chip
                  GestureDetector(
                    onTap: () => ref
                        .read(showCyclingRoutesProvider.notifier)
                        .state = !showRoutes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: showRoutes
                            ? const Color(0xFFF44336).withAlpha(25)
                            : Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: showRoutes
                                ? const Color(0xFFF44336)
                                : Colors.black26),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded,
                              color: showRoutes
                                  ? const Color(0xFFF44336)
                                  : Colors.black38,
                              size: 16),
                          const SizedBox(width: 4),
                          Text(
                            isRo ? 'Hartă risc' : 'Risk Map',
                            style: TextStyle(
                              color: showRoutes
                                  ? const Color(0xFFF44336)
                                  : Colors.black38,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isRent) ...[
                        _LegendChip(
                          color: const Color(0xFF1565C0),
                          icon: Icons.pedal_bike_rounded,
                          label: isRo ? 'Închiriere' : 'Rental',
                        ),
                        const SizedBox(width: 8),
                      ],
                      _LegendChip(
                        color: const Color(0xFF6A1B9A),
                        icon: Icons.local_parking_rounded,
                        label: isRo ? 'Parcare' : 'Parking',
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Route Info Card (shown when user taps a cycling route) ───────────
          if (_selectedRoute != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _RouteInfoCard(
                route: _selectedRoute!,
                isRo: isRo,
                onClose: () => setState(() => _selectedRoute = null),
              ),
            ),

          // ── Locate Me ────────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: (isNavigate && origin != null && destination != null) ? 200 : 100,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.primary,
              elevation: 4,
              onPressed: _locateMe,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // ── Navigate: Report FAB (inside Stack, no overlap) ──────────────────
          if (isNavigate && (origin == null || destination == null))
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton.extended(
                heroTag: 'report',
                onPressed: _showReportSheet,
                icon: const Icon(Icons.add_alert_rounded),
                label: const Text('Report',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _maybeFetchRoutes(LatLng? from, LatLng? to) async {
    if (from == null || to == null) return;
    setState(() {
      _loadingRoutes = true;
      _routeOptions = [];
    });
    try {
      final svc = RoutingService();
      final opts = await svc.getCyclingRouteOptions(from, to);
      if (mounted) {
        setState(() {
          _routeOptions = opts
              .map((o) => _CyclingRoute(
                    label: o.label,
                    summary: o.summary,
                    points: o.points,
                    color: o.color,
                    icon: o.icon,
                  ))
              .toList();
          _selectedRouteIdx = 1; // balanced by default
          _loadingRoutes = false;
        });
        if (_routeOptions.isNotEmpty) {
          final pts = _routeOptions[_selectedRouteIdx].points;
          if (pts.length >= 2) {
            final bounds = LatLngBounds.fromPoints(pts);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(40, 200, 40, 260),
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  void _showMusicSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MusicSheet(),
    );
  }

  void _onMapTap(LatLng latlng) {
    // Prioritise route info tap over navigation destination
    if (ref.read(showCyclingRoutesProvider)) {
      final routes =
          ref.read(cyclingRoutesProvider).valueOrNull ?? const [];
      final hit = nearestRoute(routes, latlng);
      if (hit != null) {
        setState(() => _selectedRoute = hit);
        return;
      }
    }
    setState(() => _selectedRoute = null);
    if (_mapMode == _MapMode.navigate && !ref.read(rideProvider).isActive) {
      if (_pickStep == _PickStep.pickingOrigin) {
        ref.read(rideOriginProvider.notifier).state = latlng;
        setState(() => _pickStep = _PickStep.none);
        _maybeFetchRoutes(latlng, ref.read(navigationDestinationProvider));
      } else if (_pickStep == _PickStep.pickingDest) {
        ref.read(navigationDestinationProvider.notifier).state = latlng;
        setState(() => _pickStep = _PickStep.none);
        _maybeFetchRoutes(ref.read(rideOriginProvider), latlng);
      }
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
    setState(() {
      _pickStep = _PickStep.none;
      _routeOptions = [];
    });

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
            // Notify about blocked lanes
            if (type == ReportType.blockedLane) {
              NotificationService().showBlockedLane('your current location').ignore();
            }
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

  Marker _buildOriginMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 44,
      height: 44,
      child: const Icon(
        Icons.trip_origin_rounded,
        color: Colors.green,
        size: 40,
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

// ─── Navigation Search Panel (integrated FROM/TO with quick-pick) ─────────────
class _NavigationSearchPanel extends ConsumerWidget {
  final LatLng? origin;
  final LatLng? destination;
  final _PickStep pickStep;
  final bool isRo;
  final LatLng? currentPos;
  final void Function(LatLng) onOriginSet;
  final void Function(LatLng) onDestinationSet;
  final VoidCallback onPickOriginFromMap;
  final VoidCallback onPickDestFromMap;
  final VoidCallback onClearOrigin;
  final VoidCallback onClearDest;

  const _NavigationSearchPanel({
    required this.origin,
    required this.destination,
    required this.pickStep,
    required this.isRo,
    required this.currentPos,
    required this.onOriginSet,
    required this.onDestinationSet,
    required this.onPickOriginFromMap,
    required this.onPickDestFromMap,
    required this.onClearOrigin,
    required this.onClearDest,
  });

  String _fmtLatLng(LatLng l) =>
      '${l.latitude.toStringAsFixed(4)}, ${l.longitude.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickingOrigin = pickStep == _PickStep.pickingOrigin;
    final pickingDest = pickStep == _PickStep.pickingDest;

    return Material(
      elevation: 5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FROM row
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: origin != null
                      ? Text(_fmtLatLng(origin!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                      : pickingOrigin
                          ? Text(
                              isRo ? 'Atinge harta…' : 'Tap map…',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12),
                            )
                          : Wrap(
                              spacing: 6,
                              children: [
                                _QuickChip(
                                  label: isRo ? 'Locația mea' : 'My location',
                                  icon: Icons.my_location_rounded,
                                  color: Colors.green,
                                  onTap: currentPos != null
                                      ? () => onOriginSet(currentPos!)
                                      : null,
                                ),
                                _QuickChip(
                                  label: isRo ? 'Hartă' : 'Map',
                                  icon: Icons.touch_app_rounded,
                                  color: Colors.green,
                                  onTap: onPickOriginFromMap,
                                ),
                              ],
                            ),
                ),
                if (origin != null)
                  GestureDetector(
                    onTap: onClearOrigin,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.black38),
                  ),
              ],
            ),
            const Divider(height: 14, indent: 26),
            // TO row
            Row(
              children: [
                const Icon(Icons.location_pin, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: destination != null
                      ? Text(_fmtLatLng(destination!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                      : pickingDest
                          ? Text(
                              isRo ? 'Atinge harta…' : 'Tap map…',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 28,
                                    child: TextField(
                                      style: const TextStyle(fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: isRo
                                            ? 'Destinație...'
                                            : 'Destination...',
                                        hintStyle: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black38),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (v) {
                                        // Geocoding placeholder — snap to Sector 2 centre
                                        onDestinationSet(const LatLng(
                                            kSector2Lat + 0.01,
                                            kSector2Lon + 0.01));
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _QuickChip(
                                  label: isRo ? 'Hartă' : 'Map',
                                  icon: Icons.touch_app_rounded,
                                  color: Colors.red,
                                  onTap: onPickDestFromMap,
                                ),
                              ],
                            ),
                ),
                if (destination != null)
                  GestureDetector(
                    onTap: onClearDest,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.black38),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Music Toggle Button (mini floating icon on map) ─────────────────────────
class _MusicToggleButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _MusicToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(musicProvider).isPlaying;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isPlaying ? AppTheme.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          border: Border.all(
            color: isPlaying ? AppTheme.primary : Colors.black12,
          ),
        ),
        child: Icon(
          isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
          color: isPlaying ? Colors.white : Colors.black38,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Music Sheet (mini player bottom sheet) ───────────────────────────────────
class _MusicSheet extends ConsumerWidget {
  const _MusicSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(musicProvider);
    final notifier = ref.read(musicProvider.notifier);
    final track = music.currentTrack;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Album art placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note_rounded,
                color: AppTheme.primary, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            track.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            track.artist,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Progress bar
          if (music.duration.inSeconds > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: music.position.inSeconds
                      .clamp(0, music.duration.inSeconds)
                      .toDouble(),
                  max: music.duration.inSeconds.toDouble(),
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.black12,
                  onChanged: (_) {}, // stream radio — no seeking
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: notifier.previous,
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 36,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: notifier.playPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    music.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: notifier.next,
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 36,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Active Driving Bar (compact header shown during an active ride) ──────────
class _ActiveDrivingBar extends ConsumerWidget {
  final bool isRo;
  const _ActiveDrivingBar({required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.directions_bike_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              isRo ? 'În deplasare' : 'Riding',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${ride.distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const SizedBox(width: 12),
            Text(
              _fmt(ride.elapsed),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

// ─── Route Options Panel ──────────────────────────────────────────────────────
class _RouteOptionsPanel extends StatelessWidget {
  final List<_CyclingRoute> routes;
  final bool loading;
  final int selectedIdx;
  final bool isRo;
  final void Function(int) onSelect;

  const _RouteOptionsPanel({
    required this.routes,
    required this.loading,
    required this.selectedIdx,
    required this.isRo,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Se calculează rutele…',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              )
            : routes.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      for (int i = 0; i < routes.length; i++) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onSelect(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: i == selectedIdx
                                    ? routes[i].color.withAlpha(30)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: i == selectedIdx
                                      ? routes[i].color
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(routes[i].icon,
                                      color: routes[i].color, size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    routes[i].label,
                                    style: TextStyle(
                                        color: routes[i].color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    routes[i].summary,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (i < routes.length - 1)
                          const SizedBox(
                              height: 40,
                              child: VerticalDivider(width: 12)),
                      ]
                    ],
                  ),
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

// ─── Route Info Card ──────────────────────────────────────────────────────────
class _RouteInfoCard extends StatelessWidget {
  final CyclingRouteFeature route;
  final bool isRo;
  final VoidCallback onClose;

  const _RouteInfoCard({
    required this.route,
    required this.isRo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final label = riskLabel(route.riskClass, isRo: isRo);
    final km = route.lengthKm;
    final lengthStr =
        km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(2)} km';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: route.color, width: 5)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, -4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            // Risk class badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: route.color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${route.riskClass ?? '?'}',
                  style: TextStyle(
                    color: route.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRo
                        ? 'Infrastructură ciclism'
                        : 'Cycling Infrastructure',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: route.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: route.color.withAlpha(120), width: 1),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: route.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.straighten_rounded,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 3),
                      Text(
                        lengthStr,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}
