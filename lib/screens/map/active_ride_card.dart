import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../providers/map_provider.dart';
import '../../widgets/app_button.dart';

/// Persistent bottom card shown when a navigation destination is set.
/// Displays live distance & elapsed time, plus Start / Finish controls.
class ActiveRideCard extends ConsumerWidget {
  final LatLng destination;
  final VoidCallback onFinish;

  const ActiveRideCard({
    super.key,
    required this.destination,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(rideProvider);
    final isActive = rideState.isActive;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats row ─────────────────────────────────────────────────────
          if (isActive)
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: '${rideState.distanceKm.toStringAsFixed(2)} km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                    icon: Icons.timer_outlined,
                    label: 'Time',
                    value: _formatDuration(rideState.elapsed),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                    icon: Icons.eco_outlined,
                    label: 'CO₂ Saved',
                    value:
                        '${(rideState.distanceKm * 120).toStringAsFixed(0)} g',
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Destination set — ready to ride!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.subtleText,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref
                      .read(navigationDestinationProvider.notifier)
                      .state = null,
                ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Action button ─────────────────────────────────────────────────
          if (isActive)
            AppButton(
              label: 'Finish Ride',
              onPressed: onFinish,
              backgroundColor: AppTheme.errorColor,
              icon: Icons.flag_rounded,
            )
          else
            AppButton(
              label: 'Start Ride',
              onPressed: () =>
                  ref.read(rideProvider.notifier).startRide(),
              icon: Icons.play_arrow_rounded,
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '${d.inMinutes}:$s';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
