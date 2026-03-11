import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/achievement_model.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/locale_provider.dart';

/// Shows all achievements (unlocked and locked) in a filterable grid.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementCategory? _filter; // null = show all

  @override
  Widget build(BuildContext context) {
    final ach = ref.watch(achievementProvider);
    final isRo = ref.watch(isRomanianProvider);

    final unlockedMap = {for (final u in ach.unlocked) u.achievementId: u};

    final filtered = _filter == null
        ? kAllAchievements
        : kAllAchievements.where((d) => d.category == _filter).toList();

    final unlockedCount = kAllAchievements.where((d) => ach.isUnlocked(d.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Realizări' : 'Achievements'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CategoryFilter(
            selected: _filter,
            isRo: isRo,
            onChanged: (c) => setState(() => _filter = c),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Progress header
          SliverToBoxAdapter(
            child: _ProgressHeader(
              unlocked: unlockedCount,
              total: kAllAchievements.length,
              isRo: isRo,
            ),
          ),
          // Achievement grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final def = filtered[i];
                  final unlocked = unlockedMap[def.id];
                  return _AchievementCard(
                    def: def,
                    unlocked: unlocked,
                    isRo: isRo,
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category filter chips ────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final AchievementCategory? selected;
  final bool isRo;
  final void Function(AchievementCategory?) onChanged;

  const _CategoryFilter({
    required this.selected,
    required this.isRo,
    required this.onChanged,
  });

  static const _labels = {
    null: ('All', 'Toate'),
    AchievementCategory.riding: ('Riding', 'Pedalare'),
    AchievementCategory.eco: ('Eco', 'Eco'),
    AchievementCategory.social: ('Social', 'Social'),
    AchievementCategory.safety: ('Safety', 'Siguranță'),
    AchievementCategory.civic: ('Civic', 'Civic'),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _labels.entries.map((e) {
          final label = isRo ? e.value.$2 : e.value.$1;
          final active = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: active,
              onSelected: (_) => onChanged(e.key),
              selectedColor: AppTheme.primary.withAlpha(30),
              checkmarkColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: active ? AppTheme.primary : AppTheme.subtleText,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: active ? AppTheme.primary : AppTheme.dividerColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Progress header ──────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  final bool isRo;

  const _ProgressHeader({
    required this.unlocked,
    required this.total,
    required this.isRo,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRo
                ? '$unlocked din $total realizări deblocate'
                : '$unlocked of $total achievements unlocked',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single achievement card ──────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final AchievementDef def;
  final UnlockedAchievement? unlocked;
  final bool isRo;

  const _AchievementCard({
    required this.def,
    required this.unlocked,
    required this.isRo,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = unlocked != null;
    final tc = def.tierColor;

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? tc.withAlpha(100) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: tc.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji + tier badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  def.emoji,
                  style: TextStyle(
                    fontSize: 34,
                    color: isUnlocked ? null : null,
                  ),
                ),
                if (isUnlocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: tc.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      def.tierLabel,
                      style: TextStyle(
                        color: tc,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              def.title(isRo),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isUnlocked ? AppTheme.onSurface : Colors.grey.shade500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Description
            Expanded(
              child: Text(
                def.desc(isRo),
                style: TextStyle(
                  fontSize: 11,
                  color: isUnlocked
                      ? AppTheme.subtleText
                      : Colors.grey.shade400,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Unlock date
            if (isUnlocked && unlocked != null)
              Text(
                DateFormat('dd MMM yyyy').format(unlocked!.unlockedAt),
                style: TextStyle(
                  fontSize: 10,
                  color: tc,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
