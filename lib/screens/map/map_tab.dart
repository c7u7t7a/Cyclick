import 'package:flutter/material.dart';
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
import '../../providers/weather_provider.dart';
import '../../services/routing_service.dart';
import '../../services/weather_service.dart';
import '../../widgets/weather_banner.dart';
import '../../widgets/mapbox_gl_widget.dart';
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
  final _geoController = MapboxGlController();
  final _searchCtrl = TextEditingController();

  // heading smoothing — previous value used to avoid jitter on small changes
  double _smoothedHeading = -1.0;

  // ── Last-synced state (avoids redundant JS calls) ─────────────────────────
  LatLng? _lastPos;
  String? _lastReportsHash;
  String? _lastRentalsHash;
  String? _lastParkingsHash;
  String? _lastGeoHash;
  String? _lastRouteHash;
  LatLng? _lastOrigin;
  LatLng? _lastDest;

  _MapMode? _mapMode;
  _PickStep _pickStep = _PickStep.none;
  RentalStation? _selectedStation;
  int _walkingMinutes = 0;
  CyclingRouteFeature? _selectedRoute;

  // Three route alternatives (safe / balanced / fast)
  List<_CyclingRoute> _routeOptions = [];
  int _selectedRouteIdx = 1; // default: balanced
  bool _loadingRoutes = false;
  bool _showParking = true;

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
    final heading = ref.watch(currentHeadingProvider);
    final routes =
        ref.watch(cyclingRoutesProvider).valueOrNull ?? const [];

    // ── Heading-based map rotation (Waze style) ─────────────────────────────
    final isActive = ref.watch(rideProvider).isActive;
    if (isActive && isNavigate && heading >= 0) {
      if (_smoothedHeading < 0 || (heading - _smoothedHeading).abs() > 3) {
        _smoothedHeading = heading;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _geoController.setBearing(heading);
          _geoController.setCamera(
            lat: ref.read(currentPositionProvider)?.latitude ?? kSector2Lat,
            lng: ref.read(currentPositionProvider)?.longitude ?? kSector2Lon,
            zoom: kNavigationZoom,
            bearing: heading,
            pitch: 60,
          );
        });
      }
    }
    final showRoutes = ref.watch(showCyclingRoutesProvider);

    // ── Sync all map state to the WebView (post-frame, delta-only) ────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // User position
      if (currentPos != null && currentPos != _lastPos) {
        _lastPos = currentPos;
        _geoController.setUserMarker(
          currentPos.latitude,
          currentPos.longitude,
          heading,
          isActive && isNavigate,
        );
        // ── Third-person camera follow during active ride ──────────────
        if (isActive && isNavigate) {
          _geoController.setCamera(
            lat: currentPos.latitude,
            lng: currentPos.longitude,
            zoom: kNavigationZoom,
            bearing: _smoothedHeading >= 0 ? _smoothedHeading : 0,
            pitch: 60,
            animate: true,
          );
        }
      }

      // Origin marker
      if (origin != _lastOrigin) {
        _lastOrigin = origin;
        if (origin != null) {
          _geoController.setOriginMarker(origin.latitude, origin.longitude);
        } else {
          _geoController.clearOriginMarker();
        }
      }

      // Destination marker
      if (destination != _lastDest) {
        _lastDest = destination;
        if (destination != null) {
          _geoController.setDestMarker(destination.latitude, destination.longitude);
        } else {
          _geoController.clearDestMarker();
        }
      }

      // Report markers
      final reportsKey = reports.map((r) => r.id).join(',');
      if (reportsKey != _lastReportsHash) {
        _lastReportsHash = reportsKey;
        _geoController.setReportMarkers(reports.map((r) => {
          'lat': r.latitude,
          'lng': r.longitude,
          'emoji': _reportEmoji(r.type),
          'label': r.type.label,
        }).toList());
      }

      // Rental markers (rent mode)
      final rentalsKey = '${isRent}_${rentals.map((s) => '${s.id}${_selectedStation?.id == s.id}').join()}';
      if (rentalsKey != _lastRentalsHash) {
        _lastRentalsHash = rentalsKey;
        if (isRent) {
          _geoController.setRentalMarkers(rentals.map((s) => {
            'id': s.id,
            'lat': s.latLng.latitude,
            'lng': s.latLng.longitude,
            'selected': _selectedStation?.id == s.id,
          }).toList());
        } else {
          _geoController.setRentalMarkers(const []);
        }
      }

      // Parking markers
      final parkingKey = '$_showParking${parkings.length}';
      if (parkingKey != _lastParkingsHash) {
        _lastParkingsHash = parkingKey;
        _geoController.setParkingMarkers(
          parkings.map((p) => {
            'lat': p.latLng.latitude,
            'lng': p.latLng.longitude,
            'name': p.name,
          }).toList(),
          _showParking,
        );
      }

      // GeoJSON cycling infrastructure layer
      final geoKey = '${routes.length}_$showRoutes';
      if (geoKey != _lastGeoHash) {
        _lastGeoHash = geoKey;
        _geoController.setGeoJsonRoutes(
          routes.map((f) => {
            'color': _colorToHex(f.color),
            'segs': f.segments.map((seg) =>
              seg.map((p) => [p.latitude, p.longitude]).toList()
            ).toList(),
          }).toList(),
          showRoutes,
        );
      }

      // Route polylines
      final routeKey = '${_routeOptions.length}_$_selectedRouteIdx';
      if (routeKey != _lastRouteHash) {
        _lastRouteHash = routeKey;
        if (_routeOptions.isEmpty) {
          _geoController.clearRoutePolylines();
        } else {
          _geoController.drawRoutePolylines(
            _routeOptions.map((r) => {
              'color': _colorToHex(r.color),
              'coords': r.points.map((p) => [p.latitude, p.longitude]).toList(),
            }).toList(),
            _selectedRouteIdx,
          );
        }
      }

      // Camera pitch: navigate = 45°, other modes = 0°
      if (isNavigate && !isActive) {
        _geoController.setPitch(45);
      } else if (!isNavigate) {
        _geoController.setPitch(0);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 3D Map (Mapbox GL JS in WebView) ──────────────────────────────
          Positioned.fill(
            child: MapboxGlWidget(
              controller: _geoController,
              onTap: (lat, lng) => _onMapTap(LatLng(lat, lng)),
              onRouteHit: (segIdx) {
                final r = ref.read(cyclingRoutesProvider).valueOrNull ?? const [];
                if (segIdx < r.length) setState(() => _selectedRoute = r[segIdx]);
              },
              onRentalTap: (id) {
                final r = ref.read(rentalProvider).valueOrNull ?? const <RentalStation>[];
                final station = r.where((s) => s.id == id).firstOrNull;
                if (station != null) _selectStation(station);
              },
            ),
          ),

          // ── Search / Navigation Panel + Mode/Music controls ─────────────────
          // Hidden during active ride — _ActiveRideHud has its own top bar.
          if (!isActive)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Search bar (left) + Navigate chip & icons (right) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: search / driving bar
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
                        // Right: Navigate chip + icon pills below it
                        if (_mapMode != null) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ModeChip(
                                mode: _mapMode!,
                                isRo: isRo,
                                onTap: _showModePicker,
                              ),
                              const SizedBox(height: 8),
                              // ── Icon row: music · risk · parking ─────────
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MusicToggleButton(
                                    onTap: () => _showMusicSheet(context),
                                  ),
                                  const SizedBox(width: 6),
                                  _MapToggleIconButton(
                                    icon: Icons.route_rounded,
                                    active: showRoutes,
                                    activeColor: const Color(0xFFF44336),
                                    tooltip:
                                        isRo ? 'Hartă risc' : 'Risk Map',
                                    onTap: () => ref
                                        .read(showCyclingRoutesProvider
                                            .notifier)
                                        .state = !showRoutes,
                                  ),
                                  const SizedBox(width: 6),
                                  _MapToggleIconButton(
                                    icon: Icons.local_parking_rounded,
                                    active: _showParking,
                                    activeColor: const Color(0xFF6A1B9A),
                                    tooltip: isRo ? 'Parcare' : 'Parking',
                                    onTap: () => setState(
                                        () => _showParking = !_showParking),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    // ── Weather banner below the whole top row ─────────────
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: WeatherBanner(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Navigate: Route Options Panel ────────────────────────────────
          // ── Navigate: Route Options Panel (hidden during active ride) ─────
          if (isNavigate && origin != null && destination != null &&
              !ref.watch(rideProvider).isActive)
            Positioned(
              bottom: 140,
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

          // ── Navigate: Start Ride Card (only when NOT active) ──────────────
          if (isNavigate && origin != null && destination != null &&
              !ref.watch(rideProvider).isActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ActiveRideCard(
                  onStart: _onStartRide,
                  onFinish: _finishRide),
            ),

          // ── 3D Active Ride HUD (full-screen overlay while riding) ─────────
          if (isNavigate && ref.watch(rideProvider).isActive)
            Positioned.fill(
              child: _ActiveRideHud(
                destination: destination,
                routePoints: _routeOptions.isNotEmpty
                    ? _routeOptions[_selectedRouteIdx].points
                    : const [],
                isRo: isRo,
                onFinish: _finishRide,
                onReport: _showReportSheet,
              ),
            ),

          // ── Rent: Station Card ───────────────────────────────────────────
          if (isRent && _selectedStation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StationCard(
                station: _selectedStation!,
                walkingMinutes: _walkingMinutes,
                isRo: isRo,
                onClose: _closeStation,
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

          // ── Locate Me (hidden during active ride) ─────────────────────────
          if (!ref.watch(rideProvider).isActive)
          Positioned(
            right: 16,
            bottom: (isNavigate && origin != null && destination != null) ? 260 : 100,
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

  Future<void> _onStartRide() async {
    final weather = ref.read(weatherProvider).valueOrNull;
    final isRo = ref.read(isRomanianProvider);
    if (weather != null && weather.isAlert) {
      NotificationService().showWeatherAlert(weather, isRo: isRo);
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StartRideDialog(weather: weather, isRo: isRo),
    );
    if (confirmed == true && mounted) {
      await ref.read(rideProvider.notifier).startRide();
      final pos = ref.read(currentPositionProvider);
      if (pos != null) {
        final startHeading = ref.read(currentHeadingProvider);
      _geoController.setCamera(
          lat: pos.latitude,
          lng: pos.longitude,
          zoom: kNavigationZoom,
          bearing: startHeading >= 0 ? startHeading : 0,
          pitch: 60,
          animate: true,
        );
      }
    }
  }

  Future<void> _maybeFetchRoutes(LatLng? from, LatLng? to) async {
    if (from == null || to == null) return;
    setState(() {
      _loadingRoutes = true;
      _routeOptions = [];
      _lastRouteHash = null; // force redraw
    });
    try {
      final geoJsonRoutes =
          ref.read(cyclingRoutesProvider).valueOrNull ?? const [];
      final svc = RoutingService();
      final opts = await svc.getCyclingRouteOptions(from, to,
          geoJsonRoutes: geoJsonRoutes);
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
          _selectedRouteIdx = 0; // slot 0 = GeoJSON "Rute Aprobate" or safest
          _loadingRoutes = false;
        });
        if (_routeOptions.isNotEmpty) {
          final pts = _routeOptions[_selectedRouteIdx].points;
          if (pts.length >= 2) {
            _geoController.fitBounds(
              pts.map((p) => [p.latitude, p.longitude]).toList(),
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
    // Route-hit events come through the dedicated onRouteHit callback.
    // Plain map taps either set navigation origin/destination or close the route card.
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
      _walkingMinutes = 0;
      _lastRentalsHash = null; // force rental marker redraw with new selection
    });
    if (pos != null) {
      final svc = RoutingService();
      final route = await svc.getWalkingPolyline(pos, station.latLng);
      final mins = await svc.getWalkingMinutes(pos, station.latLng);
      if (mounted) {
        setState(() => _walkingMinutes = mins);
        if (route.length >= 2) {
          _geoController.drawWalkingRoute(
            route.map((p) => [p.latitude, p.longitude]).toList(),
          );
        }
      }
    }
    _geoController.jumpTo(station.latLng.latitude, station.latLng.longitude, 15.5);
  }

  Future<void> _locateMe() async {
    final locService = ref.read(locationServiceProvider);
    final pos = await locService.getCurrentPosition();
    if (pos != null && mounted) {
      final latlng = LatLng(pos.latitude, pos.longitude);
      ref.read(currentPositionProvider.notifier).state = latlng;
      _geoController.jumpTo(latlng.latitude, latlng.longitude, kNavigationZoom);
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

  // ── WebView map helper utilities ───────────────────────────────────────────

  String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  String _reportEmoji(ReportType type) {
    return switch (type) {
      ReportType.blockedLane          => '🚧',
      ReportType.dangerousIntersection => '⚠️',
      ReportType.pothole              => '🕳️',
      ReportType.safeZone             => '🛡️',
      ReportType.uncleanedPath        => '🧹',
    };
  }

  // ── Station close (clear walking route) ───────────────────────────────────
  void _closeStation() {
    setState(() {
      _selectedStation = null;
      _lastRentalsHash = null;
    });
    _geoController.clearWalkingRoute();
  }
}

// ─── Map toggle icon button (top-right panel) ───────────────────────────────────────────
class _MapToggleIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;
  const _MapToggleIconButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? activeColor.withAlpha(35) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: active ? activeColor : Colors.black12, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4)
            ],
          ),
          child: Icon(icon,
              color: active ? activeColor : Colors.black38, size: 17),
        ),
      ),
    );
  }
}

// ─── Start Ride safety dialog ──────────────────────────────────────────────────────
class _StartRideDialog extends StatelessWidget {
  final WeatherData? weather;
  final bool isRo;
  const _StartRideDialog({this.weather, required this.isRo});

  @override
  Widget build(BuildContext context) {
    final hasBadWeather = weather?.isAlert ?? false;
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      title: Row(
        children: [
          const Icon(Icons.sports_motorsports_rounded,
              color: AppTheme.primary, size: 26),
          const SizedBox(width: 10),
          Text(
            isRo ? 'Înainte să pleci' : 'Before you go',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SafetyItem(
            icon: Icons.sports_motorsports_rounded,
            color: AppTheme.primary,
            text: isRo
                ? 'Poartă casca de protecție'
                : 'Wear your helmet',
          ),
          const SizedBox(height: 8),
          _SafetyItem(
            icon: Icons.flashlight_on_rounded,
            color: Colors.amber.shade700,
            text: isRo
                ? 'Verifică luminile față / spate'
                : 'Check front & rear lights',
          ),
          const SizedBox(height: 8),
          _SafetyItem(
            icon: Icons.security_rounded,
            color: Colors.orange.shade700,
            text: isRo
                ? 'Poartă vestă reflectorizantă'
                : 'Wear a reflective vest',
          ),
          if (hasBadWeather && weather != null) ...[
            const SizedBox(height: 8),
            _SafetyItem(
              icon: weather!.icon,
              color: weather!.color,
              text: isRo ? weather!.alertMessageRo : weather!.alertMessage,
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isRo ? 'Anulează' : 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(isRo ? 'Pornesc!' : "Let's go!"),
        ),
      ],
    );
  }
}

class _SafetyItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _SafetyItem(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color.withAlpha(210),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3D Active Ride HUD (full-screen overlay — Waze-style) ───────────────────
class _ActiveRideHud extends ConsumerWidget {
  final LatLng? destination;
  final List<LatLng> routePoints;
  final bool isRo;
  final VoidCallback onFinish;
  final VoidCallback onReport;

  const _ActiveRideHud({
    required this.destination,
    required this.routePoints,
    required this.isRo,
    required this.onFinish,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final speedKmh = ride.distanceKm > 0 && ride.elapsed.inSeconds > 0
        ? (ride.distanceKm / ride.elapsed.inSeconds * 3600)
        : 0.0;

    // ETA based on remaining distance (rough)
    final remainingKm = routePoints.isNotEmpty && destination != null
        ? const Distance().as(
            LengthUnit.Kilometer,
            ref.read(currentPositionProvider) ?? destination!,
            destination!,
          )
        : 0.0;
    final etaMins = speedKmh > 1
        ? (remainingKm / speedKmh * 60).ceil()
        : (remainingKm * 5).ceil(); // ~12 km/h default

    return Column(
      children: [
        // ── Top bar ─────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_bike_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isRo
                                ? 'În deplasare…'
                                : 'Riding…',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.primary),
                          ),
                          if (destination != null)
                            Text(
                              isRo
                                  ? 'Destinație: ${destination!.latitude.toStringAsFixed(4)}, ${destination!.longitude.toStringAsFixed(4)}'
                                  : 'To: ${destination!.latitude.toStringAsFixed(4)}, ${destination!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Report button — same pill style as the normal-map FAB
                    ElevatedButton.icon(
                      onPressed: onReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        elevation: 2,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.add_alert_rounded, size: 16),
                      label: const Text('Report',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const Spacer(),

        // ── Bottom HUD ───────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HudStat(
                    icon: Icons.speed_rounded,
                    value: speedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    color: speedKmh > 25
                        ? Colors.red
                        : AppTheme.primary,
                  ),
                  _HudDivider(),
                  _HudStat(
                    icon: Icons.straighten_rounded,
                    value: ride.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                    color: AppTheme.primary,
                  ),
                  _HudDivider(),
                  _HudStat(
                    icon: Icons.timer_rounded,
                    value: _fmtDuration(ride.elapsed),
                    unit: '',
                    color: Colors.black87,
                  ),
                  _HudDivider(),
                  _HudStat(
                    icon: Icons.flag_rounded,
                    value: etaMins > 0 ? '$etaMins' : '--',
                    unit: 'min',
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Finish button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: onFinish,
                  icon: const Icon(Icons.stop_circle_rounded, size: 22),
                  label: Text(
                    isRo ? 'Finalizează cursa' : 'Finish Ride',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

class _HudStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;
  const _HudStat(
      {required this.icon,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Colors.black45),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HudDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
    );
  }
}

// ─── Navigation Search Panel (integrated FROM/TO with quick-pick) ───────────────
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
