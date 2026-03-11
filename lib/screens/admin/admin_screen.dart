import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/rental_provider.dart';
import '../../providers/parking_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/community_route_provider.dart';
import '../../widgets/mapbox_gl_widget.dart';

/// Emails that always have admin access (hackathon bypass).
const _hardcodedAdmins = {'lazarcristi720@gmail.com'};

/// Role check — first checks hardcoded list, then DB flag.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  // Hardcoded bypass — works even if migrations haven't been run yet
  if (_hardcodedAdmins.contains(user.email?.toLowerCase())) return true;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();
    return row?['is_admin'] as bool? ?? false;
  } catch (_) {
    return false;
  }
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRo = ref.watch(isRomanianProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Panou Admin' : 'Admin Panel'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: isRo ? 'Feedback' : 'Feedback'),
            Tab(text: isRo ? 'Închirieri' : 'Rentals'),
            Tab(text: isRo ? 'Parcări' : 'Parking'),
            Tab(text: isRo ? 'Top Rute' : 'Top Routes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedbackTab(isRo: isRo),
          _RentalAdminTab(isRo: isRo),
          _ParkingAdminTab(isRo: isRo),
          _TopRoutesTab(isRo: isRo),
        ],
      ),
    );
  }
}

// ─── Feedback Tab ────────────────────────────────────────────────────────────
class _FeedbackTab extends ConsumerWidget {
  final bool isRo;
  const _FeedbackTab({required this.isRo});

  static Future<List<Map<String, dynamic>>> _loadFeedback() async {
    try {
      // Tries SECURITY DEFINER RPC that bypasses RLS to see all users' feedback.
      // Run migration 006_admin_functions.sql in Supabase dashboard to enable this.
      final r = await Supabase.instance.client.rpc('get_all_feedback');
      return List<Map<String, dynamic>>.from(r as List);
    } catch (_) {
      // Fallback: only own rides (RLS restriction)
      final r = await Supabase.instance.client
          .from('ride_history')
          .select('id, started_at, distance_km, safety_rating, feedback_tags, city_hall_message')
          .order('started_at', ascending: false);
      return List<Map<String, dynamic>>.from(r as List);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localRides = ref.watch(historyProvider);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadFeedback(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final dbRows = snap.data ?? [];
        // Fall back to in-memory seed/loaded rides when Supabase is empty
        final rows = dbRows.isNotEmpty
            ? dbRows
            : localRides
                .map((r) => <String, dynamic>{
                      'id': r.id,
                      'started_at': r.startedAt.toIso8601String(),
                      'distance_km': r.distanceKm,
                      'safety_rating': r.safetyRating,
                      'feedback_tags': r.feedbackTags,
                      'city_hall_message': r.cityHallMessage,
                    })
                .toList();
        if (rows.isEmpty) {
          return Center(
              child: Text(isRo
                  ? 'Niciun feedback încă.'
                  : 'No feedback yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            final date = DateTime.tryParse(r['started_at'] as String? ?? '');
            final tags =
                (r['feedback_tags'] as List<dynamic>? ?? []).join(', ');
            final msg = r['city_hall_message'] as String?;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          date != null
                              ? '${date.day}/${date.month}/${date.year}'
                              : '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        if (r['safety_rating'] != null)
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 16),
                            Text(
                                (r['safety_rating'] as num).toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ]),
                        const SizedBox(width: 8),
                        Text(
                            '${(r['distance_km'] as num?)?.toStringAsFixed(1) ?? '-'} km',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(tags,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                    if (msg != null && msg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.account_balance_rounded,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(msg,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Rental Admin Tab ────────────────────────────────────────────────────────
class _RentalAdminTab extends ConsumerWidget {
  final bool isRo;
  const _RentalAdminTab({required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentals = ref.watch(rentalProvider).valueOrNull ?? [];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            final picked = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(builder: (_) => const _PinPickerScreen()),
            );
            if (picked != null && context.mounted) {
              _showAddStation(context, ref, isRo, picked);
            }
          },
          icon: const Icon(Icons.add_location_alt_rounded),
          label: Text(isRo ? 'Adaugă stație' : 'Add station'),
        ),
        const SizedBox(height: 12),
        ...rentals.map((s) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.pedal_bike_rounded,
                    color: Color(0xFF1565C0)),
                title: Text(s.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${s.availableBikes}/${s.totalDocks} ${isRo ? 'disponibile' : 'available'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () =>
                      _showEditAvailability(context, ref, s, isRo),
                ),
              ),
            )),
      ],
    );
  }

  void _showAddStation(BuildContext ctx, WidgetRef ref, bool isRo, LatLng picked) {
    final nameCtrl = TextEditingController();
    final docksCtrl = TextEditingController(text: '10');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isRo ? 'Stație nouă' : 'New Station'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: isRo ? 'Nume' : 'Name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: docksCtrl,
              decoration: InputDecoration(labelText: isRo ? 'Locuri totale' : 'Total docks'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isRo ? 'Anulează' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(rentalProvider.notifier).addStation(RentalStation(
                id: 'rs-${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim().isEmpty
                    ? 'Stație ${DateTime.now().millisecond}'
                    : nameCtrl.text.trim(),
                latitude: picked.latitude,
                longitude: picked.longitude,
                availableBikes: 0,
                totalDocks: int.tryParse(docksCtrl.text) ?? 10,
              ));
              Navigator.pop(dialogCtx);
            },
            child: Text(isRo ? 'Salvează' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showEditAvailability(
      BuildContext ctx, WidgetRef ref, RentalStation s, bool isRo) {
    final ctrl = TextEditingController(text: '${s.availableBikes}');
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(s.name),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
              labelText: isRo ? 'Biciclete disponibile' : 'Available bikes'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(rentalProvider.notifier).updateAvailability(
                s.id, int.tryParse(ctrl.text) ?? s.availableBikes);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Parking Admin Tab ───────────────────────────────────────────────────────
class _ParkingAdminTab extends ConsumerWidget {
  final bool isRo;
  const _ParkingAdminTab({required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(parkingProvider).valueOrNull ?? [];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            final picked = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(builder: (_) => const _PinPickerScreen()),
            );
            if (picked != null && context.mounted) {
              _showAddParking(context, ref, isRo, picked);
            }
          },
          icon: const Icon(Icons.add_location_alt_rounded),
          label: Text(isRo ? 'Adaugă parcare' : 'Add parking'),
        ),
        const SizedBox(height: 12),
        ...parkings.map((p) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.local_parking_rounded,
                    color: Color(0xFF6A1B9A)),
                title: Text(p.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.capacity} spots'
                    '${p.isCovered ? (isRo ? ' • acoperit' : ' • covered') : ''}'),
              ),
            )),
      ],
    );
  }

  void _showAddParking(BuildContext ctx, WidgetRef ref, bool isRo, LatLng picked) {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '10');
    bool covered = false;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setState) {
        return AlertDialog(
          title: Text(isRo ? 'Parcare nouă' : 'New Parking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: isRo ? 'Nume' : 'Name'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: capCtrl,
                decoration: InputDecoration(labelText: isRo ? 'Capacitate' : 'Capacity'),
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                value: covered,
                onChanged: (v) => setState(() => covered = v ?? false),
                title: Text(isRo ? 'Acoperit' : 'Covered'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isRo ? 'Anulează' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(parkingProvider.notifier).addParking(BikeParking(
                  id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim().isEmpty
                      ? 'Parcare ${DateTime.now().millisecond}'
                      : nameCtrl.text.trim(),
                  latitude: picked.latitude,
                  longitude: picked.longitude,
                  capacity: int.tryParse(capCtrl.text) ?? 10,
                  isCovered: covered,
                ));
                Navigator.pop(dialogCtx);
              },
              child: Text(isRo ? 'Salvează' : 'Save'),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Top Routes Admin Tab ────────────────────────────────────────────────────
class _TopRoutesTab extends ConsumerStatefulWidget {
  final bool isRo;
  const _TopRoutesTab({required this.isRo});

  @override
  ConsumerState<_TopRoutesTab> createState() => _TopRoutesTabState();
}

class _TopRoutesTabState extends ConsumerState<_TopRoutesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final now = DateTime.now();
    setState(() {
      _future = Supabase.instance.client
          .from('community_routes')
          .select('id, name, author_name, likes, downvotes, created_at')
          .order('likes', ascending: false)
          .limit(100)
          .then((r) {
            final rows = List<Map<String, dynamic>>.from(r as List);
            // Filter to current month and compute score
            var thisMonth = rows.where((row) {
              final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
              return dt != null &&
                  dt.year == now.year &&
                  dt.month == now.month;
            }).toList();
            thisMonth.sort((a, b) {
              final sa = ((a['likes'] as num? ?? 0) -
                  (a['downvotes'] as num? ?? 0));
              final sb = ((b['likes'] as num? ?? 0) -
                  (b['downvotes'] as num? ?? 0));
              return sb.compareTo(sa);
            });
            var ranked = thisMonth.take(3).toList().asMap().entries.map((e) {
              return {...e.value, 'rank': e.key + 1};
            }).toList();
            // Fall back to in-memory seed routes when Supabase has nothing
            if (ranked.isEmpty) {
              final seedRoutes =
                  ref.read(communityRouteProvider).value ?? [];
              final seedThisMonth = seedRoutes
                  .where((s) =>
                      s.createdAt.year == now.year &&
                      s.createdAt.month == now.month)
                  .toList()
                ..sort((a, b) => b.score.compareTo(a.score));
              ranked = seedThisMonth
                  .take(3)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => <String, dynamic>{
                        'name': e.value.name,
                        'author_name': e.value.authorName,
                        'likes': e.value.likes,
                        'downvotes': e.value.downvotes,
                        'rank': e.key + 1,
                      })
                  .toList();
            }
            return ranked;
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRo = widget.isRo;
    final now = DateTime.now();
    final monthLabel = [
      '', 'Ian', 'Feb', 'Mar', 'Apr', 'Mai', 'Iun',
      'Iul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthEN = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final heading = isRo
        ? 'Top 3 rute — ${monthLabel[now.month]} ${now.year}'
        : 'Top 3 routes — ${monthEN[now.month]} ${now.year}';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final routes = snap.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AppTheme.primary.withAlpha(15),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFC107), size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _fetch,
                    tooltip: isRo ? 'Reîncarcă' : 'Refresh',
                  ),
                ],
              ),
            ),
            // Route list
            Expanded(
              child: routes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.route_rounded,
                              size: 56, color: Colors.black26),
                          const SizedBox(height: 12),
                          Text(
                            isRo
                                ? 'Nicio rută votată luna aceasta.'
                                : 'No routes voted this month.',
                            style: const TextStyle(
                                color: Colors.black45, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: routes.length,
                      itemBuilder: (_, i) {
                        final r = routes[i];
                        final rank = (r['rank'] as num).toInt();
                        final medal = rank <= 3 ? _medals[rank - 1] : '#$rank';
                        final name = r['name'] as String? ?? '-';
                        final author = r['author_name'] as String? ?? '-';
                        final likes = r['likes'] as num? ?? 0;
                        final downvotes = r['downvotes'] as num? ?? 0;
                        final score = likes - downvotes;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: rank == 1 ? 4 : 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text(medal,
                                    style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isRo
                                            ? 'de $author'
                                            : 'by $author',
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: score >= 0
                                        ? Colors.deepOrange.withAlpha(20)
                                        : const Color(0xFF5F4BB6).withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    score >= 0 ? '+$score' : '$score',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: score >= 0
                                          ? Colors.deepOrange
                                          : const Color(0xFF5F4BB6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Pin Picker Screen ────────────────────────────────────────────────────────
/// Full-screen Mapbox map where the admin taps to drop a pin and confirm.
class _PinPickerScreen extends StatefulWidget {
  const _PinPickerScreen();

  @override
  State<_PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<_PinPickerScreen> {
  final _ctrl = MapboxGlController();
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop a pin'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_picked != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: const Text(
                'Confirm',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          MapboxGlWidget(
            controller: _ctrl,
            onTap: (lat, lng) {
              setState(() => _picked = LatLng(lat, lng));
              _ctrl.setDestMarker(lat, lng);
            },
            onRouteHit: (_) {},
            onRentalTap: (_) {},
          ),

          // ── Hint pill ────────────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _picked == null
                          ? Icons.touch_app_rounded
                          : Icons.location_on_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _picked == null
                          ? 'Tap on the map to place a pin'
                          : '${_picked!.latitude.toStringAsFixed(5)}, '
                              '${_picked!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          if (_picked != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SafeArea(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context, _picked),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Confirm location',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
