import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';

/// Fetches all ride_history rows for the current user that have a
/// city_hall_message, and shows them as a list of submitted suggestions.
final _cityHallReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.user?.id;
  if (uid == null) return [];
  final rows = await Supabase.instance.client
      .from('ride_history')
      .select()
      .eq('user_id', uid)
      .not('city_hall_message', 'is', null)
      .order('started_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

class CityHallReportsScreen extends ConsumerWidget {
  const CityHallReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRo = ref.watch(isRomanianProvider);
    final reportsAsync = ref.watch(_cityHallReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Sesizările Mele' : 'My City Hall Reports'),
      ),
      body: reportsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.subtleText),
              const SizedBox(height: 12),
              Text(isRo ? 'Eroare la încărcare' : 'Failed to load',
                  style: const TextStyle(color: AppTheme.subtleText)),
            ],
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_outlined,
                      size: 56, color: AppTheme.subtleText),
                  const SizedBox(height: 16),
                  Text(
                    isRo
                        ? 'Nu ai trimis nicio sesizare încă.'
                        : 'You haven\'t submitted any reports yet.',
                    style: const TextStyle(
                        color: AppTheme.subtleText, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRo
                        ? 'Feedback-ul de după cursă poate include mesaje pentru Primărie.'
                        : 'Post-ride feedback can include messages for City Hall.',
                    style: const TextStyle(
                        color: AppTheme.subtleText, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: reports.length,
            itemBuilder: (ctx, i) {
              final r = reports[i];
              final date = DateTime.tryParse(
                      r['started_at'] as String? ?? '') ??
                  DateTime.now();
              final message = r['city_hall_message'] as String? ?? '';
              final rating =
                  (r['safety_rating'] as num?)?.toDouble();
              final tags =
                  List<String>.from(r['feedback_tags'] as List? ?? []);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${date.day}.${date.month}.${date.year}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary),
                            ),
                          ),
                          const Spacer(),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 3),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: tags
                              .map((t) => Chip(
                                    label: Text(t,
                                        style: const TextStyle(
                                            fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize
                                            .shrinkWrap,
                                    side: BorderSide.none,
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: 0.08),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.pending_rounded,
                              color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isRo
                                ? 'În așteptare · Primăria Sector 2'
                                : 'Pending · Sector 2 City Hall',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
