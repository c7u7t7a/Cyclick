import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/locale_provider.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class PrivacyPrefs {
  final bool shareLocationOnMap;
  final bool anonymousRoutes;
  final bool shareAnonymousAnalytics;

  const PrivacyPrefs({
    this.shareLocationOnMap = true,
    this.anonymousRoutes = false,
    this.shareAnonymousAnalytics = true,
  });

  PrivacyPrefs copyWith({
    bool? shareLocationOnMap,
    bool? anonymousRoutes,
    bool? shareAnonymousAnalytics,
  }) =>
      PrivacyPrefs(
        shareLocationOnMap: shareLocationOnMap ?? this.shareLocationOnMap,
        anonymousRoutes: anonymousRoutes ?? this.anonymousRoutes,
        shareAnonymousAnalytics:
            shareAnonymousAnalytics ?? this.shareAnonymousAnalytics,
      );
}

class _PrivacyNotifier extends StateNotifier<PrivacyPrefs> {
  _PrivacyNotifier() : super(const PrivacyPrefs());
  void toggle(String key) {
    state = switch (key) {
      'shareLocationOnMap' =>
        state.copyWith(shareLocationOnMap: !state.shareLocationOnMap),
      'anonymousRoutes' =>
        state.copyWith(anonymousRoutes: !state.anonymousRoutes),
      'shareAnonymousAnalytics' =>
        state.copyWith(shareAnonymousAnalytics: !state.shareAnonymousAnalytics),
      _ => state,
    };
  }
}

final privacyPrefsProvider =
    StateNotifierProvider<_PrivacyNotifier, PrivacyPrefs>(
        (_) => _PrivacyNotifier());

// ─── Screen ──────────────────────────────────────────────────────────────────

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRo = ref.watch(isRomanianProvider);
    final prefs = ref.watch(privacyPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Confidențialitate' : 'Privacy'),
      ),
      body: ListView(
        children: [
          _Section(label: isRo ? 'Localizare' : 'Location'),
          _PrivTile(
            icon: Icons.location_on_rounded,
            title: isRo ? 'Distribuie localizarea pe hartă' : 'Share location on map',
            subtitle: isRo
                ? 'Ceilalți cicliști te pot vedea în timp real pe harta comunitară'
                : 'Other cyclists can see you live on the community map',
            value: prefs.shareLocationOnMap,
            onChanged: (_) => ref
                .read(privacyPrefsProvider.notifier)
                .toggle('shareLocationOnMap'),
          ),
          _Section(label: isRo ? 'Profil & Rute' : 'Profile & Routes'),
          _PrivTile(
            icon: Icons.person_off_rounded,
            title: isRo ? 'Rute anonime' : 'Anonymous Routes',
            subtitle: isRo
                ? 'Rutele tale vor apărea fără numele tău în comunitate'
                : 'Your routes will appear without your name in the community',
            value: prefs.anonymousRoutes,
            onChanged: (_) => ref
                .read(privacyPrefsProvider.notifier)
                .toggle('anonymousRoutes'),
          ),
          _Section(label: isRo ? 'Date & Analiză' : 'Data & Analytics'),
          _PrivTile(
            icon: Icons.analytics_rounded,
            title: isRo
                ? 'Analiză anonimă de utilizare'
                : 'Anonymous usage analytics',
            subtitle: isRo
                ? 'Ne ajuți să îmbunătățim aplicația fără date personale'
                : 'Help us improve the app without sharing personal data',
            value: prefs.shareAnonymousAnalytics,
            onChanged: (_) => ref
                .read(privacyPrefsProvider.notifier)
                .toggle('shareAnonymousAnalytics'),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: AppTheme.primary.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isRo ? 'Datele tale sunt în siguranță' : 'Your data is safe',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRo
                          ? 'Cyclick stochează doar datele necesare funcționării aplicației. Nu vindem și nu partajăm date cu terți. Datele sunt protejate prin Row Level Security în Supabase.'
                          : 'Cyclick stores only the data needed to run the app. We never sell or share data with third parties. Data is protected via Row Level Security in Supabase.',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.subtleText),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAccount(context, isRo),
              icon: const Icon(Icons.delete_forever_rounded,
                  color: AppTheme.errorColor),
              label: Text(
                isRo ? 'Șterge contul' : 'Delete Account',
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, bool isRo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRo ? 'Șterge contul?' : 'Delete account?'),
        content: Text(isRo
            ? 'Toate datele tale vor fi șterse permanent. Această acțiune nu poate fi anulată.'
            : 'All your data will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isRo ? 'Anulează' : 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRo ? 'Șterge' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});
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

class _PrivTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrivTile({
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
