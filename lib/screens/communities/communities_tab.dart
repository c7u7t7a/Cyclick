import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/community_group_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/locale_provider.dart';
import 'community_routes_screen.dart';

/// Social hub — Sector 2 group rides to help cyclists ride safely together.
class CommunitiesTab extends ConsumerWidget {
  const CommunitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(communityProvider);
    final isRo = ref.watch(isRomanianProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Curse Comunitate' : 'Community Rides'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CommunityRoutesScreen()),
            ),
            icon: const Icon(Icons.route_rounded),
            tooltip: isRo ? 'Rute' : 'Routes',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showCreateGroupDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isRo ? 'Organizează' : 'Organize'),
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
            child: groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load rides: $e')),
              data: (groups) => groups.isEmpty
                  ? const Center(
                      child: Text(
                        'No rides yet.\nBe the first to organize one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: groups.length,
                      itemBuilder: (context, i) =>
                          _GroupCard(group: groups[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupSheet(),
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

// ─── Create Group Sheet ───────────────────────────────────────────────────────
class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _meetCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  DateTime _rideDate = DateTime.now().add(const Duration(days: 1, hours: 8));
  int _maxParticipants = 20;
  SafetyLevel _safetyLevel = SafetyLevel.medium;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _meetCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(communityProvider.notifier).createGroup(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            rideDate: _rideDate,
            meetingPoint: _meetCtrl.text.trim(),
            meetingLat: 44.4340,
            meetingLon: 26.1080,
            maxParticipants: _maxParticipants,
            safetyLevel: _safetyLevel,
            routeDescription: _routeCtrl.text.trim().isNotEmpty
                ? _routeCtrl.text.trim()
                : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _rideDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_rideDate),
    );
    if (time == null) return;
    setState(() {
      _rideDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM · HH:mm').format(_rideDate);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Organize a Group Ride',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ride name *',
                  hintText: 'e.g. Saturday Morning Loop',
                  prefixIcon: Icon(Icons.edit_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date & time *',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(dateStr,
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _meetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meeting point *',
                  hintText: 'e.g. Parcul IOR, Intrarea A',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Meeting point is required'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.group_rounded,
                      color: AppTheme.subtleText, size: 20),
                  const SizedBox(width: 12),
                  const Text('Max participants:',
                      style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _maxParticipants,
                    items: [10, 15, 20, 25, 30, 40, 50]
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _maxParticipants = v!),
                    underline: const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Safety level:',
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.subtleText)),
              const SizedBox(height: 8),
              Row(
                children: SafetyLevel.values.map((level) {
                  final selected = _safetyLevel == level;
                  final isLast = level == SafetyLevel.high;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _safetyLevel = level),
                      child: Container(
                        margin:
                            EdgeInsets.only(right: isLast ? 0 : 8),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? level.color.withAlpha(38)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? level.color
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(level.icon,
                                color: level.color, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              level.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: level.color,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _routeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route description (optional)',
                  hintText:
                      'e.g. Parcul IOR → Bd. Camil Ressu → Piața Muncii',
                  prefixIcon: Icon(Icons.route_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Create →'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
