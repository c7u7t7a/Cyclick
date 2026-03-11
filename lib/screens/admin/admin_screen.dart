import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/rental_provider.dart';
import '../../providers/parking_provider.dart';
import '../../providers/locale_provider.dart';

/// Role check — admin flag stored in profiles table.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('is_admin')
        .eq('id', uid)
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
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRo = ref.watch(isRomanianProvider);
    final isAdminAsync = ref.watch(isAdminProvider);

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
          ],
        ),
      ),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error checking admin role')),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 64, color: Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    isRo
                        ? 'Acces restricționat'
                        : 'Access restricted',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRo
                        ? 'Contul tău nu are drepturi de administrator.'
                        : 'Your account does not have admin privileges.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _FeedbackTab(isRo: isRo),
              _RentalAdminTab(isRo: isRo),
              _ParkingAdminTab(isRo: isRo),
            ],
          );
        },
      ),
    );
  }
}

// ─── Feedback Tab ────────────────────────────────────────────────────────────
class _FeedbackTab extends ConsumerWidget {
  final bool isRo;
  const _FeedbackTab({required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('ride_history')
          .select('id, started_at, distance_km, safety_rating, feedback_tags, city_hall_message')
          .order('started_at', ascending: false)
          .limit(50)
          .then((r) => List<Map<String, dynamic>>.from(r as List)),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? [];
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
          onPressed: () => _showAddStation(context, ref, isRo),
          icon: const Icon(Icons.add),
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

  void _showAddStation(
      BuildContext ctx, WidgetRef ref, bool isRo) {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '44.45');
    final lonCtrl = TextEditingController(text: '26.11');
    final docksCtrl = TextEditingController(text: '10');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title:
            Text(isRo ? 'Stație nouă' : 'New Station'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lonCtrl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            TextField(controller: docksCtrl, decoration: const InputDecoration(labelText: 'Total docks'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(rentalProvider.notifier).addStation(RentalStation(
                id: 'rs-${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                latitude: double.tryParse(latCtrl.text) ?? kSector2LatFallback,
                longitude: double.tryParse(lonCtrl.text) ?? kSector2LonFallback,
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
          onPressed: () => _showAddParking(context, ref, isRo),
          icon: const Icon(Icons.add),
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

  void _showAddParking(BuildContext ctx, WidgetRef ref, bool isRo) {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '44.45');
    final lonCtrl = TextEditingController(text: '26.11');
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
              TextField(controller: lonCtrl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
              TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
              CheckboxListTile(
                value: covered,
                onChanged: (v) => setState(() => covered = v ?? false),
                title: Text(isRo ? 'Acoperit' : 'Covered'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ref.read(parkingProvider.notifier).addParking(BikeParking(
                  id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  latitude: double.tryParse(latCtrl.text) ?? kSector2LatFallback,
                  longitude: double.tryParse(lonCtrl.text) ?? kSector2LonFallback,
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

const double kSector2LatFallback = 44.4557;
const double kSector2LonFallback = 26.1162;
