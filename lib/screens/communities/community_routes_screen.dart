import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/mapbox_token.dart';
import '../../core/theme.dart';
import '../../providers/community_route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class CommunityRoutesScreen extends ConsumerWidget {
  const CommunityRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRo = ref.watch(isRomanianProvider);
    final routesAsync = ref.watch(communityRouteProvider);
    final selected = ref.watch(selectedRouteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Rute Comunitate' : 'Community Routes'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) => Column(
          children: [
            // Map preview of selected route
            if (selected != null)
              SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: selected.waypoints.isNotEmpty
                        ? selected.waypoints[selected.waypoints.length ~/ 2]
                        : const LatLng(kSector2Lat, kSector2Lon),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                        urlTemplate:
                            '$kMapboxStyleUrl?access_token=$kMapboxPublicToken',
                        userAgentPackageName: 'com.cyclick.app',
                        tileProvider: NetworkTileProvider()),
                    PolylineLayer(polylines: [
                      Polyline(
                        points: selected.waypoints,
                        color: AppTheme.primary,
                        strokeWidth: 4,
                      )
                    ]),
                    MarkerLayer(markers: [
                      if (selected.waypoints.isNotEmpty)
                        Marker(
                          point: selected.waypoints.first,
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.radio_button_checked,
                              color: Colors.green, size: 28),
                        ),
                      if (selected.waypoints.length > 1)
                        Marker(
                          point: selected.waypoints.last,
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.flag_rounded,
                              color: Colors.red, size: 28),
                        ),
                    ]),
                  ],
                ),
              ),
            // Top 3 this month
            _TopThisMonth(routes: routes, isRo: isRo),
            // Route list
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: routes.length,
                itemBuilder: (ctx, i) {
                  final r = routes[i];
                  final isSelected = selected?.id == r.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.transparent,
                            width: 2)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => ref
                          .read(selectedRouteProvider.notifier)
                          .state = isSelected ? null : r,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _difficultyColor(r.difficulty)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.route_rounded,
                                  color: _difficultyColor(r.difficulty),
                                  size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(r.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${r.authorName}  •  '
                                    '${r.distanceKm.toStringAsFixed(1)} km  •  '
                                    '${r.durationMinutes} min',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _VoteButtons(route: r),
                                const SizedBox(height: 4),
                                _DifficultyBadge(d: r.difficulty, isRo: isRo),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRouteSheet(context, ref, isRo),
        icon: const Icon(Icons.add),
        label: Text(isRo ? 'Adaugă Rută' : 'Add Route'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Color _difficultyColor(String d) {
    if (d == 'easy') return Colors.green;
    if (d == 'hard') return Colors.red;
    return Colors.orange;
  }

  void _showAddRouteSheet(
      BuildContext context, WidgetRef ref, bool isRo) {
    final nameCtrl = TextEditingController();
    String difficulty = 'easy';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(builder: (ctx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isRo ? 'Adaugă Rută' : 'Add Route',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isRo ? 'Nume rută' : 'Route name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(isRo ? 'Dificultate' : 'Difficulty',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'easy',
                      label: Text(isRo ? 'Ușor' : 'Easy')),
                  ButtonSegment(
                      value: 'medium',
                      label: Text(isRo ? 'Mediu' : 'Medium')),
                  ButtonSegment(
                      value: 'hard',
                      label: Text(isRo ? 'Greu' : 'Hard')),
                ],
                selected: {difficulty},
                onSelectionChanged: (s) =>
                    setState(() => difficulty = s.first),
              ),
              const SizedBox(height: 16),
              Text(
                isRo
                    ? 'Notă: ruta va folosi GPS-ul curent al cursei tale.'
                    : 'Note: route will use your current ride GPS track.',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final user =
                        ref.read(authStateProvider).valueOrNull?.user;
                    final route = CommunityRoute(
                      id: 'cr-${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text.trim(),
                      authorId: user?.id ?? '',
                      authorName: user?.name ?? 'Anonymous',
                      waypoints: const [
                        LatLng(kSector2Lat, kSector2Lon),
                      ],
                      distanceKm: 0,
                      durationMinutes: 0,
                      difficulty: difficulty,
                      createdAt: DateTime.now(),
                    );
                    ref
                        .read(communityRouteProvider.notifier)
                        .addRoute(route);
                    Navigator.pop(ctx);
                  },
                  child: Text(isRo ? 'Salvează' : 'Save'),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String d;
  final bool isRo;
  const _DifficultyBadge({required this.d, required this.isRo});

  @override
  Widget build(BuildContext context) {
    final color = d == 'easy'
        ? Colors.green
        : d == 'hard'
            ? Colors.red
            : Colors.orange;
    String label;
    if (isRo) {
      label = d == 'easy' ? 'Ușor' : d == 'hard' ? 'Greu' : 'Mediu';
    } else {
      label = d[0].toUpperCase() + d.substring(1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

// ─── Reddit-style Vote Buttons ────────────────────────────────────────────────
class _VoteButtons extends ConsumerWidget {
  final CommunityRoute route;
  const _VoteButtons({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upvoted = route.userVote == 1;
    final downvoted = route.userVote == -1;
    final score = route.score;
    final scoreColor = score > 0
        ? Colors.deepOrange
        : score < 0
            ? const Color(0xFF5F4BB6)
            : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ▲ Upvote
          _VoteButton(
            icon: Icons.arrow_upward_rounded,
            active: upvoted,
            activeColor: Colors.deepOrange,
            onTap: () => ref
                .read(communityRouteProvider.notifier)
                .vote(route.id, 1),
          ),
          // Score
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              score > 0 ? '+$score' : '$score',
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          // ▼ Downvote
          _VoteButton(
            icon: Icons.arrow_downward_rounded,
            active: downvoted,
            activeColor: const Color(0xFF5F4BB6),
            onTap: () => ref
                .read(communityRouteProvider.notifier)
                .vote(route.id, -1),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _VoteButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? activeColor.withAlpha(30) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? activeColor : Colors.black45,
          ),
        ),
      );
}

// ─── Top 3 This Month ─────────────────────────────────────────────────────────
class _TopThisMonth extends StatelessWidget {
  final List<CommunityRoute> routes;
  final bool isRo;
  const _TopThisMonth({required this.routes, required this.isRo});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = routes
        .where((r) =>
            r.createdAt.year == now.year && r.createdAt.month == now.month)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final top3 = top.take(3).toList();

    if (top3.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withAlpha(18),
            const Color(0xFF1A237E).withAlpha(12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primary.withAlpha(40), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFC107), size: 18),
              const SizedBox(width: 6),
              Text(
                isRo ? 'Top 3 luna aceasta' : 'Top 3 this month',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A237E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...top3.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final score = r.score;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(_medals[i],
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        Text(r.authorName,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: score >= 0
                          ? Colors.deepOrange.withAlpha(20)
                          : const Color(0xFF5F4BB6).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      score >= 0 ? '+$score' : '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: score >= 0
                            ? Colors.deepOrange
                            : const Color(0xFF5F4BB6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
