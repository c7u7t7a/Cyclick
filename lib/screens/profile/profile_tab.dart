import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_button.dart';
import '../admin/admin_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'city_hall_reports_screen.dart';

/// User settings, stats, and bicycle details.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  static const _bicycleTypes = [
    'City',
    'Mountain',
    'Road',
    'Gravel',
    'E-Bike',
    'BMX',
    'Other',
  ];

  void _showAbout(BuildContext context, bool isRo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.pedal_bike_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Cyclick',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('v1.0.0',
                style:
                    TextStyle(fontSize: 13, color: AppTheme.subtleText)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              isRo
                  ? 'Waze pentru ciclism urban — harta vie a Sectorului 2, București.\n\nConstruit pentru Hackathonul Living Map, martie 2026.'
                  : 'Waze for urban cycling — the living map of Sector 2, Bucharest.\n\nBuilt for the Living Map Hackathon, March 2026.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.map_rounded, size: 14, color: AppTheme.subtleText),
                SizedBox(width: 4),
                Text('OpenStreetMap  •  OpenMeteo  •  OSRM',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtleText)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Supabase  •  Flutter  •  Riverpod',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.subtleText)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isRo ? 'Închide' : 'Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final user = authState?.user;
    final rides = ref.watch(historyProvider);

    // Compute lifetime stats from history
    final totalKm =
        rides.fold<double>(0, (s, r) => s + r.distanceKm);
    final totalCo2 =
        rides.fold<double>(0, (s, r) => s + r.co2SavedGrams);
    final isRomanian = ref.watch(isRomanianProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(isRomanian ? 'Profil' : 'Profile'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(authStateProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18,
                color: AppTheme.errorColor),
            label: Text(isRomanian ? 'Ieșire' : 'Sign Out',
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Avatar & name ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(user.email,
                    style: const TextStyle(
                        color: AppTheme.subtleText, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Lifetime stats ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Impact',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ImpactStat(
                        icon: Icons.straighten_rounded,
                        value: '${totalKm.toStringAsFixed(1)} km',
                        label: 'Total Distance',
                      ),
                      _ImpactStat(
                        icon: Icons.route_rounded,
                        value: '${rides.length}',
                        label: 'Total Rides',
                      ),
                      _ImpactStat(
                        icon: Icons.eco_rounded,
                        value:
                            '${(totalCo2 / 1000).toStringAsFixed(2)} kg',
                        label: 'CO₂ Saved',
                        color: AppTheme.successColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Bicycle details ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Bicycle',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.pedal_bike_rounded,
                          color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BicycleDropdown(
                          current: user.bicycleType,
                          types: _bicycleTypes,
                          onChanged: (type) async {
                            await Supabase.instance.client
                                .from('profiles')
                                .update({'bicycle_type': type})
                                .eq('id', user.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Settings ─────────────────────────────────────────────────────
          Card(
            child: Column(
              children: [
                // Language toggle
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: AppTheme.primary),
                  title: Text(isRomanian ? 'Limbă' : 'Language'),
                  subtitle: Text(isRomanian ? 'Română' : 'English'),
                  trailing: Switch(
                    value: isRomanian,
                    activeThumbColor: AppTheme.primary,
                    activeTrackColor: AppTheme.primary.withAlpha(128),
                    onChanged: (v) => ref.read(isRomanianProvider.notifier).toggle(),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: isRomanian ? 'Notificări curse' : 'Ride Notifications',
                  subtitle: isRomanian ? 'Reamintiri de grup și alerte de siguranță' : 'Group ride reminders and safety alerts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: isRomanian ? 'Confidențialitate' : 'Privacy',
                  subtitle: isRomanian ? 'Gestionează preferințele de localizare' : 'Manage your location sharing preferences',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.account_balance_outlined,
                  title: isRomanian ? 'Rapoarte Primărie' : 'City Hall Reports',
                  subtitle: isRomanian ? 'Vezi toate sesizările tale de infrastructură' : 'View all your infrastructure suggestions submitted',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CityHallReportsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                // Admin Panel link
                _SettingsTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: isRomanian ? 'Panou Admin' : 'Admin Panel',
                  subtitle: isRomanian ? 'Feedback, stații și parcări' : 'Feedback, stations & parking',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About Cyclick',
                  subtitle: 'v1.0.0 · Sector 2 Living Map Hackathon',
                  onTap: () => _showAbout(context, isRomanian),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: isRomanian ? 'Ieșire din cont' : 'Sign Out',
            backgroundColor: AppTheme.errorColor,
            icon: Icons.logout_rounded,
            onPressed: () =>
                ref.read(authStateProvider.notifier).signOut(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _ImpactStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: c),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.subtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BicycleDropdown extends StatefulWidget {
  final String? current;
  final List<String> types;
  final void Function(String) onChanged;

  const _BicycleDropdown({
    required this.current,
    required this.types,
    required this.onChanged,
  });

  @override
  State<_BicycleDropdown> createState() => _BicycleDropdownState();
}

class _BicycleDropdownState extends State<_BicycleDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current ?? widget.types.first;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _selected,
      decoration: const InputDecoration(labelText: 'Bicycle Type'),
      items: widget.types
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selected = val);
          widget.onChanged(val);
        }
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.subtleText),
      onTap: onTap,
    );
  }
}
