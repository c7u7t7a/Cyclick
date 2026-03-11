import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/mapbox_token.dart';
import '../../core/theme.dart';
import '../../providers/rental_provider.dart';
import '../../providers/parking_provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/routing_service.dart';

class RentalTab extends ConsumerStatefulWidget {
  const RentalTab({super.key});

  @override
  ConsumerState<RentalTab> createState() => _RentalTabState();
}

class _RentalTabState extends ConsumerState<RentalTab> {
  final _mapController = MapController();
  List<Latln> _walkingRoute = [];
  RentalStation? _selectedStation;
  int _walkingMinutes = 0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
      final route =
          await svc.getWalkingPolyline(pos, station.latLng);
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

  @override
  Widget build(BuildContext context) {
    final isRo = ref.watch(isRomanianProvider);
    final rentals = ref.watch(rentalProvider).valueOrNull ?? [];
    final parkings = ref.watch(parkingProvider).valueOrNull ?? [];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(kSector2Lat, kSector2Lon),
              initialZoom: 13.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    '$kMapboxStyleUrl?access_token=$kMapboxPublicToken',
                userAgentPackageName: 'com.cyclick.app',
                tileProvider: NetworkTileProvider(),
              ),
              // Walking route polyline
              if (_walkingRoute.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _walkingRoute,
                    color: AppTheme.primary,
                    strokeWidth: 4,
                    isDotted: true,
                  )
                ]),
              // Rental station markers
              MarkerLayer(
                markers: rentals.map((s) {
                  final isSelected = _selectedStation?.id == s.id;
                  return Marker(
                    point: s.latLng,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _selectStation(s),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF1565C0),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 3 : 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.pedal_bike_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Parking markers
              MarkerLayer(
                markers: parkings.map((p) => Marker(
                      point: p.latLng,
                      width: 36,
                      height: 36,
                      child: Tooltip(
                        message:
                            '${p.name} (${p.capacity} spots${p.isCovered ? ', acoperit' : ''})',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A1B9A),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.local_parking_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    )).toList(),
              ),
            ],
          ),

          // ── Station card ──────────────────────────────────────────────────
          if (_selectedStation != null)
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

          // ── Top row legend ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Row(
              children: [
                _LegendChip(
                    color: const Color(0xFF1565C0),
                    icon: Icons.pedal_bike_rounded,
                    label: isRo ? 'Închiriere' : 'Rental'),
                const SizedBox(width: 8),
                _LegendChip(
                    color: const Color(0xFF6A1B9A),
                    icon: Icons.local_parking_rounded,
                    label: isRo ? 'Parcare' : 'Parking'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))
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
                  constraints: const BoxConstraints()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.dock_rounded,
                label: '${station.totalDocks} docks',
                color: Colors.grey,
              ),
              if (walkingMinutes > 0) ...[
                const SizedBox(width: 8),
                _StatPill(
                  icon: Icons.directions_walk_rounded,
                  label: isRo
                      ? '$walkingMinutes min pe jos'
                      : '$walkingMinutes min walk',
                  color: const Color(0xFF1565C0),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
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

// Typedef alias to avoid import clash
typedef Latln = LatLng;
