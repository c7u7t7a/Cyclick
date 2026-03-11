import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../models/achievement_model.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_button.dart';
import '../admin/admin_screen.dart';
import 'achievements_screen.dart';
import 'city_hall_reports_screen.dart';
import 'friend_profile_screen.dart';
import 'friends_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

// ─── XP helpers ───────────────────────────────────────────────────────────────

int _xpFromStats(int rides, double km, int unlockedAchievements) =>
    (rides * 50) + (km * 10).round() + (unlockedAchievements * 75);

int _level(int xp) => xp ~/ 500;

double _levelProgress(int xp) => (xp % 500) / 500.0;

// ─── Main tab ─────────────────────────────────────────────────────────────────

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  static const _bicycleTypes = [
    'City', 'Mountain', 'Road', 'Gravel', 'E-Bike', 'BMX', 'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final user = authState?.user;
    final rides = ref.watch(historyProvider);
    final achState = ref.watch(achievementProvider);
    final friendsState = ref.watch(friendsProvider);
    final isRo = ref.watch(isRomanianProvider);

    if (user == null) return const SizedBox.shrink();

    final totalKm = rides.fold<double>(0, (s, r) => s + r.distanceKm);
    final totalCo2 = rides.fold<double>(0, (s, r) => s + r.co2SavedGrams);
    final unlockedCount = achState.unlockedIds.length;

    final xp = _xpFromStats(rides.length, totalKm, unlockedCount);
    final level = _level(xp);
    final progress = _levelProgress(xp);

    // Congrats snackbar for newly unlocked achievements
    if (achState.newlyUnlocked.isNotEmpty) {
      final def = kAllAchievements
          .firstWhere((d) => d.id == achState.newlyUnlocked.first);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${def.emoji} ${isRo ? 'Realizare deblocată' : 'Achievement unlocked'}: ${def.title(isRo)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: def.tierColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          ref.read(achievementProvider.notifier).clearNewlyUnlocked();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSection(
              user: user,
              level: level,
              progress: progress,
              xp: xp,
              isRo: isRo,
              onSignOut: () => ref.read(authStateProvider.notifier).signOut(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _StatsRow(
                km: totalKm,
                rides: rides.length,
                co2Kg: totalCo2 / 1000,
                isRo: isRo,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _AchievementsSection(
              achState: achState,
              isRo: isRo,
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FriendsSection(
              friendsState: friendsState,
              isRo: isRo,
              onManage: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRo ? 'Bicicleta mea' : 'My Bicycle',
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
                              isRo: isRo,
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
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language_rounded,
                          color: AppTheme.primary),
                      title: Text(isRo ? 'Limbă' : 'Language'),
                      subtitle: Text(isRo ? 'Română' : 'English'),
                      trailing: Switch(
                        value: isRo,
                        activeThumbColor: AppTheme.primary,
                        activeTrackColor: AppTheme.primary.withAlpha(128),
                        onChanged: (_) =>
                            ref.read(isRomanianProvider.notifier).toggle(),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: isRo ? 'Notificări curse' : 'Ride Notifications',
                      subtitle: isRo
                          ? 'Reamintiri de grup și alerte de siguranță'
                          : 'Group ride reminders and safety alerts',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen())),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: isRo ? 'Confidențialitate' : 'Privacy',
                      subtitle: isRo
                          ? 'Gestionează preferințele de localizare'
                          : 'Manage your location sharing preferences',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyScreen())),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.account_balance_outlined,
                      title: isRo ? 'Rapoarte Primărie' : 'City Hall Reports',
                      subtitle: isRo
                          ? 'Vezi toate sesizările tale de infrastructură'
                          : 'View all your infrastructure suggestions submitted',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const CityHallReportsScreen())),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: isRo ? 'Panou Admin' : 'Admin Panel',
                      subtitle: isRo
                          ? 'Feedback, stații și parcări'
                          : 'Feedback, stations & parking',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AdminScreen())),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Cyclick',
                      subtitle: 'v1.0.0 · Sector 2 Living Map Hackathon',
                      onTap: () => _showAbout(context, isRo),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              child: AppButton(
                label: isRo ? 'Ieșire din cont' : 'Sign Out',
                backgroundColor: AppTheme.errorColor,
                icon: Icons.logout_rounded,
                onPressed: () => ref.read(authStateProvider.notifier).signOut(),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('v1.0.0',
                style: TextStyle(fontSize: 13, color: AppTheme.subtleText)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              isRo
                  ? 'Waze pentru ciclism urban — harta vie a Sectorului 2.\n\nConstruit pentru Hackathonul Living Map, martie 2026.'
                  : 'Waze for urban cycling — the living map of Sector 2.\n\nBuilt for the Living Map Hackathon, March 2026.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.subtleText),
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
                    style: TextStyle(fontSize: 11, color: AppTheme.subtleText)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Supabase  •  Flutter  •  Riverpod',
                style: TextStyle(fontSize: 11, color: AppTheme.subtleText)),
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
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final dynamic user;
  final int level;
  final double progress;
  final int xp;
  final bool isRo;
  final VoidCallback onSignOut;

  const _HeroSection({
    required this.user,
    required this.level,
    required this.progress,
    required this.xp,
    required this.isRo,
    required this.onSignOut,
  });

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
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRo ? 'Profil' : 'Profile',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: Text(isRo ? 'Ieșire' : 'Sign Out',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Avatar with level badge
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 3),
                    ),
                  ),
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white.withAlpha(30),
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        isRo ? 'Nivel $level' : 'Level $level',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(user.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
              const SizedBox(height: 2),
              Text(user.email,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              // XP bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$xp XP',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('${(level + 1) * 500} XP',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRo
                        ? '${(progress * 100).toStringAsFixed(0)}% spre Nivelul ${level + 1}'
                        : '${(progress * 100).toStringAsFixed(0)}% to Level ${level + 1}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
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

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double km;
  final int rides;
  final double co2Kg;
  final bool isRo;

  const _StatsRow(
      {required this.km,
      required this.rides,
      required this.co2Kg,
      required this.isRo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.straighten_rounded,
          value: '${km.toStringAsFixed(1)} km',
          label: isRo ? 'Distanță' : 'Distance',
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.route_rounded,
          value: '$rides',
          label: isRo ? 'Curse' : 'Rides',
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.eco_rounded,
          value: '${co2Kg.toStringAsFixed(2)} kg',
          label: 'CO₂',
          color: AppTheme.successColor,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}

// ─── Achievements section ─────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final AchievementState achState;
  final bool isRo;
  final VoidCallback onSeeAll;

  const _AchievementsSection(
      {required this.achState, required this.isRo, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final unlocked =
        kAllAchievements.where((d) => achState.isUnlocked(d.id)).toList();
    final total = kAllAchievements.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(isRo ? 'Realizări' : 'Achievements',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${unlocked.length}/$total',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(isRo ? 'Vezi toate' : 'See all',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (achState.loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator()))
          else if (unlocked.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isRo
                          ? 'Finalizează prima cursă pentru a debloca realizări!'
                          : 'Complete your first ride to unlock achievements!',
                      style: const TextStyle(
                          color: AppTheme.subtleText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: unlocked.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) =>
                    _AchievementBadge(def: unlocked[i], isRo: isRo),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final AchievementDef def;
  final bool isRo;

  const _AchievementBadge({required this.def, required this.isRo});

  @override
  Widget build(BuildContext context) {
    final tc = def.tierColor;
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.withAlpha(80)),
        boxShadow: [
          BoxShadow(
              color: tc.withAlpha(35),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(def.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              def.title(isRo),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  color: AppTheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: tc.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                def.tierLabel,
                style: TextStyle(
                    fontSize: 7,
                    color: tc,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Friends section ──────────────────────────────────────────────────────────

class _FriendsSection extends StatelessWidget {
  final FriendsState friendsState;
  final bool isRo;
  final VoidCallback onManage;

  const _FriendsSection(
      {required this.friendsState, required this.isRo, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final pendingCount = friendsState.pendingReceived.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(isRo ? 'Prieteni' : 'Friends',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$pendingCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: onManage,
                child: Text(isRo ? 'Gestionează' : 'Manage',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (friendsState.loading)
            const Center(child: CircularProgressIndicator())
          else if (friendsState.friends.isEmpty && pendingCount == 0)
            GestureDetector(
              onTap: onManage,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    const Text('🤝', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isRo
                            ? 'Niciun prieten încă. Apasă pentru a găsi ciclisti!'
                            : 'No friends yet. Tap to find cyclists!',
                        style: const TextStyle(
                            color: AppTheme.subtleText, fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.subtleText),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...friendsState.pendingReceived.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: onManage,
                          child: _FriendAvatar(
                              initials: f.initials,
                              name: f.name,
                              isPending: true),
                        ),
                      )),
                  ...friendsState.friends.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FriendProfileScreen(friend: f, isRo: isRo),
                            ),
                          ),
                          child: _FriendAvatar(
                            initials: f.initials,
                            name: f.name,
                            isPending: false,
                            achievementCount:
                                f.unlockedAchievementIds.length,
                          ),
                        ),
                      )),
                  _AddFriendButton(isRo: isRo, onTap: onManage),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String initials;
  final String name;
  final bool isPending;
  final int achievementCount;

  const _FriendAvatar({
    required this.initials,
    required this.name,
    required this.isPending,
    this.achievementCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPending ? AppTheme.warningColor : AppTheme.primary,
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: AppTheme.primary.withAlpha(20),
                child: Text(initials,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            if (isPending)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: AppTheme.warningColor, shape: BoxShape.circle),
                  child: const Icon(Icons.mail_rounded,
                      size: 10, color: Colors.white),
                ),
              )
            else if (achievementCount > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text('$achievementCount',
                      style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            name.split(' ').first,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  final bool isRo;
  final VoidCallback onTap;

  const _AddFriendButton({required this.isRo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.dividerColor, width: 2),
              color: AppTheme.background,
            ),
            child: const Icon(Icons.add_rounded,
                color: AppTheme.subtleText, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(isRo ? 'Adaugă' : 'Add',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.subtleText),
              textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

// ─── Bicycle dropdown ─────────────────────────────────────────────────────────

class _BicycleDropdown extends StatefulWidget {
  final String? current;
  final List<String> types;
  final bool isRo;
  final void Function(String) onChanged;

  const _BicycleDropdown({
    required this.current,
    required this.types,
    required this.isRo,
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.isRo ? 'Tip bicicletă' : 'Bicycle Type',
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          isExpanded: true,
          isDense: true,
          items: widget.types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selected = val);
              widget.onChanged(val);
            }
          },
        ),
      ),
    );
  }
}

// ─── Settings tile ────────────────────────────────────────────────────────────

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
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppTheme.subtleText),
      onTap: onTap,
    );
  }
}
