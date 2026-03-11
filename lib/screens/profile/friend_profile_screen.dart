import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/achievement_model.dart';
import '../../models/friend_model.dart';

/// Public profile of a friend — shows their stats and unlocked achievements.
class FriendProfileScreen extends StatelessWidget {
  final FriendModel friend;
  final bool isRo;

  const FriendProfileScreen({
    super.key,
    required this.friend,
    required this.isRo,
  });

  @override
  Widget build(BuildContext context) {
    // Map achievement IDs → definitions
    final unlockedDefs = kAllAchievements
        .where((d) => friend.unlockedAchievementIds.contains(d.id))
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero header ──────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(friend: friend, isRo: isRo),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Stats row ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _StatsRow(friend: friend, isRo: isRo),
            ),
          ),

          // ── Achievements grid ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isRo
                        ? 'Realizări (${unlockedDefs.length})'
                        : 'Achievements (${unlockedDefs.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (unlockedDefs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 56, color: AppTheme.dividerColor),
                    const SizedBox(height: 12),
                    Text(
                      isRo
                          ? 'Nicio realizare deblocată încă.'
                          : 'No achievements unlocked yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.subtleText),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MiniAchievementCard(
                    def: unlockedDefs[i],
                    isRo: isRo,
                  ),
                  childCount: unlockedDefs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Hero header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final FriendModel friend;
  final bool isRo;

  const _HeroHeader({required this.friend, required this.isRo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Avatar with ring
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                color: Colors.white24,
              ),
              child: Center(
                child: Text(
                  friend.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              friend.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            if (friend.bicycleType != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🚲 ${friend.bicycleType}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final FriendModel friend;
  final bool isRo;

  const _StatsRow({required this.friend, required this.isRo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(
          emoji: '🛣️',
          value: '${friend.totalKm.toStringAsFixed(1)} km',
          label: isRo ? 'Total' : 'Total',
        ),
        const SizedBox(width: 8),
        _StatPill(
          emoji: '🚴',
          value: '${friend.totalRides}',
          label: isRo ? 'Curse' : 'Rides',
        ),
        const SizedBox(width: 8),
        _StatPill(
          emoji: '🌿',
          value: '${(friend.totalCo2Grams / 1000).toStringAsFixed(2)} kg',
          label: 'CO₂',
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatPill({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withAlpha(30)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.primary,
              ),
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}

// ─── Mini achievement card (3-column grid) ────────────────────────────────────

class _MiniAchievementCard extends StatelessWidget {
  final AchievementDef def;
  final bool isRo;

  const _MiniAchievementCard({required this.def, required this.isRo});

  @override
  Widget build(BuildContext context) {
    final tc = def.tierColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.withAlpha(80)),
        boxShadow: [
          BoxShadow(color: tc.withAlpha(30), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(def.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              def.title(isRo),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: AppTheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tc.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                def.tierLabel,
                style: TextStyle(
                    fontSize: 8, color: tc, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
