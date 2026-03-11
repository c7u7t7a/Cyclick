import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/locale_provider.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class NotificationPrefs {
  final bool groupRides;
  final bool weatherAlerts;
  final bool newCommunityRoutes;
  final bool cityHallResponses;

  const NotificationPrefs({
    this.groupRides = true,
    this.weatherAlerts = true,
    this.newCommunityRoutes = false,
    this.cityHallResponses = true,
  });

  NotificationPrefs copyWith({
    bool? groupRides,
    bool? weatherAlerts,
    bool? newCommunityRoutes,
    bool? cityHallResponses,
  }) =>
      NotificationPrefs(
        groupRides: groupRides ?? this.groupRides,
        weatherAlerts: weatherAlerts ?? this.weatherAlerts,
        newCommunityRoutes: newCommunityRoutes ?? this.newCommunityRoutes,
        cityHallResponses: cityHallResponses ?? this.cityHallResponses,
      );
}

class _NotificationNotifier extends StateNotifier<NotificationPrefs> {
  _NotificationNotifier() : super(const NotificationPrefs());
  void toggle(String key) {
    state = switch (key) {
      'groupRides' => state.copyWith(groupRides: !state.groupRides),
      'weatherAlerts' => state.copyWith(weatherAlerts: !state.weatherAlerts),
      'newCommunityRoutes' =>
        state.copyWith(newCommunityRoutes: !state.newCommunityRoutes),
      'cityHallResponses' =>
        state.copyWith(cityHallResponses: !state.cityHallResponses),
      _ => state,
    };
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<_NotificationNotifier, NotificationPrefs>(
        (_) => _NotificationNotifier());

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRo = ref.watch(isRomanianProvider);
    final prefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Notificări' : 'Notifications'),
      ),
      body: ListView(
        children: [
          _SectionHeader(
              label: isRo ? 'Curse & Grupuri' : 'Rides & Groups'),
          _PrefTile(
            icon: Icons.group_rounded,
            title: isRo ? 'Curse de grup' : 'Group Rides',
            subtitle: isRo
                ? 'Reamintiri despre cursele programate ale grupului tău'
                : 'Reminders for your group\'s scheduled rides',
            value: prefs.groupRides,
            onChanged: (_) =>
                ref.read(notificationPrefsProvider.notifier).toggle('groupRides'),
          ),
          const Divider(height: 1, indent: 72),
          _PrefTile(
            icon: Icons.route_rounded,
            title: isRo ? 'Rute noi în comunitate' : 'New Community Routes',
            subtitle: isRo
                ? 'Când cineva din zona ta adaugă o rută'
                : 'When someone in your area adds a route',
            value: prefs.newCommunityRoutes,
            onChanged: (_) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle('newCommunityRoutes'),
          ),
          _SectionHeader(label: isRo ? 'Siguranță' : 'Safety'),
          _PrefTile(
            icon: Icons.thunderstorm_rounded,
            title: isRo ? 'Alerte meteo' : 'Weather Alerts',
            subtitle: isRo
                ? 'Avertizări despre condiții periculoase pe bicicletă'
                : 'Warnings for dangerous cycling conditions',
            value: prefs.weatherAlerts,
            onChanged: (_) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle('weatherAlerts'),
          ),
          _SectionHeader(label: isRo ? 'Primărie' : 'City Hall'),
          _PrefTile(
            icon: Icons.account_balance_rounded,
            title: isRo ? 'Răspunsuri primărie' : 'City Hall Responses',
            subtitle: isRo
                ? 'Actualizări privind sesizările tale de infrastructură'
                : 'Updates on your infrastructure reports',
            value: prefs.cityHallResponses,
            onChanged: (_) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle('cityHallResponses'),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isRo
                  ? 'Notificările push vor fi activate în actualizarea v1.1. Până atunci, preferințele sunt salvate local.'
                  : 'Push notifications will be enabled in the v1.1 update. Until then, preferences are saved locally.',
              style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.subtleText,
              letterSpacing: 1.1)),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.primary),
      title: Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
      value: value,
      activeTrackColor: AppTheme.primary,
      onChanged: onChanged,
    );
  }
}
