import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/ride_history_model.dart';
import '../../providers/history_provider.dart';

/// Shows a chronological list of all completed rides with key stats.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(historyProvider);

    // Aggregate totals
    final totalKm =
        rides.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final totalCo2 =
        rides.fold<double>(0, (sum, r) => sum + r.co2SavedGrams);
    final totalRides = rides.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                '$totalRides rides',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.primary.withAlpha(15),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: rides.isEmpty
          ? _EmptyState()
          : CustomScrollView(
              slivers: [
                // ── Summary banner ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SummaryBanner(
                    totalKm: totalKm,
                    totalCo2Grams: totalCo2,
                    totalRides: totalRides,
                  ),
                ),
                // ── Ride list ──────────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _RideCard(ride: rides[index]),
                    childCount: rides.length,
                  ),
                ),
                const SliverPadding(
                    padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
    );
  }
}

// ─── Summary Banner ───────────────────────────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final double totalKm;
  final double totalCo2Grams;
  final int totalRides;

  const _SummaryBanner({
    required this.totalKm,
    required this.totalCo2Grams,
    required this.totalRides,
  });

  @override
  Widget build(BuildContext context) {
    final co2Kg = (totalCo2Grams / 1000).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _BannerStat(value: totalKm.toStringAsFixed(1), label: 'Total km'),
          _divider(),
          _BannerStat(value: totalRides.toString(), label: 'Rides'),
          _divider(),
          _BannerStat(value: '$co2Kg kg', label: 'CO₂ Saved'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;

  const _BannerStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Ride Card ─────────────────────────────────────────────────────────────────
class _RideCard extends StatelessWidget {
  final RideHistoryModel ride;

  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEE, d MMM y · HH:mm').format(ride.startedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & rating row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppTheme.subtleText),
                const SizedBox(width: 6),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.subtleText)),
                const Spacer(),
                if (ride.safetyRating != null)
                  _StarRating(rating: ride.safetyRating!),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                _Stat(
                  icon: Icons.straighten_rounded,
                  value: '${ride.distanceKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 16),
                _Stat(
                  icon: Icons.timer_outlined,
                  value: ride.formattedDuration,
                ),
                const SizedBox(width: 16),
                _Stat(
                  icon: Icons.eco_outlined,
                  value: ride.formattedCo2,
                  color: AppTheme.successColor,
                ),
              ],
            ),
            // Feedback tags
            if (ride.feedbackTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ride.feedbackTags
                    .map((tag) => _TagChip(tag: tag))
                    .toList(),
              ),
            ],
            // City hall message
            if (ride.cityHallMessage != null &&
                ride.cityHallMessage!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(40)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.cityHallMessage!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.subtleText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _Stat({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: const TextStyle(
            fontSize: 11,
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded,
              size: 72, color: AppTheme.dividerColor),
          const SizedBox(height: 16),
          Text(
            'No rides yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.subtleText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set a destination on the map to start your first ride.',
            style: TextStyle(color: AppTheme.subtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
