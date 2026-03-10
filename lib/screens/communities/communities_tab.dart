import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/community_group_model.dart';
import '../../providers/community_provider.dart';

/// Social hub — Sector 2 group rides to help cyclists ride safely together.
class CommunitiesTab extends ConsumerWidget {
  const CommunitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(communityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Rides'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showCreateGroupDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Organize'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Mission banner ────────────────────────────────────────────────
          _MissionBanner(),
          const SizedBox(height: 4),
          // ── Group list ────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: groups.length,
              itemBuilder: (context, i) => _GroupCard(group: groups[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Organize a Group Ride'),
        content: const Text(
          'Group ride creation will be available once connected to Supabase.\n\n'
          'Organizers can set date, meeting point, route, and max participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ─── Mission Banner ───────────────────────────────────────────────────────────
class _MissionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride Together, Stay Safe',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Join a group ride to explore Sector 2 without the fear of cycling alone.',
                  style: TextStyle(fontSize: 12, color: AppTheme.subtleText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group Card ───────────────────────────────────────────────────────────────
class _GroupCard extends ConsumerWidget {
  final CommunityGroupModel group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        DateFormat('EEE, d MMM · HH:mm').format(group.rideDate);
    final isUpcoming = group.rideDate.isAfter(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _SafetyBadge(level: group.safetyLevel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              group.description,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.subtleText, height: 1.4),
            ),
            const SizedBox(height: 12),

            // ── Meta info ────────────────────────────────────────────────
            _InfoRow(
                icon: Icons.access_time_rounded, text: dateStr),
            const SizedBox(height: 4),
            _InfoRow(
                icon: Icons.location_on_outlined,
                text: group.meetingPoint),
            if (group.routeDescription != null) ...[
              const SizedBox(height: 4),
              _InfoRow(
                  icon: Icons.route_rounded,
                  text: group.routeDescription!),
            ],
            const SizedBox(height: 12),

            // ── Participants & Join button ────────────────────────────────
            Row(
              children: [
                // Participant avatars (mock)
                _ParticipantCounter(
                  count: group.participantCount,
                  max: group.maxParticipants,
                ),
                const Spacer(),
                if (isUpcoming)
                  _JoinButton(group: group)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Past Ride',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.subtleText),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyBadge extends StatelessWidget {
  final SafetyLevel level;
  const _SafetyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 12, color: level.color),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: TextStyle(
              fontSize: 11,
              color: level.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.subtleText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.subtleText)),
        ),
      ],
    );
  }
}

class _ParticipantCounter extends StatelessWidget {
  final int count;
  final int max;
  const _ParticipantCounter({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = count / max;
    final color = pct >= 0.9
        ? AppTheme.errorColor
        : pct >= 0.6
            ? AppTheme.warningColor
            : AppTheme.primary;

    return Row(
      children: [
        Icon(Icons.group_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$count / $max',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        const Text('cyclists',
            style: TextStyle(fontSize: 12, color: AppTheme.subtleText)),
      ],
    );
  }
}

class _JoinButton extends ConsumerWidget {
  final CommunityGroupModel group;
  const _JoinButton({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = group.isJoined;
    final full = group.isFull && !joined;

    return FilledButton(
      onPressed: full
          ? null
          : () => ref
              .read(communityProvider.notifier)
              .toggleJoin(group.id),
      style: FilledButton.styleFrom(
        backgroundColor: joined ? AppTheme.primaryDark : AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        full ? 'Full' : joined ? '✓ Joined' : 'Join',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
