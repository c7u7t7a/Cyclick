import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../providers/music_provider.dart';
import '../widgets/music_player_bar.dart';
import 'map/map_tab.dart';
import 'history/history_tab.dart';
import 'communities/communities_tab.dart';
import 'profile/profile_tab.dart';

/// Root scaffold with bottom tab navigation.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  static const _tabs = [
    MapTab(),
    HistoryTab(),
    CommunitiesTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isRo = ref.watch(isRomanianProvider);
    ref.watch(musicProvider); // keep music state alive

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          // Music player bar (always visible)
          const MusicPlayerBar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map_rounded),
            label: isRo ? 'Hartă' : 'Map',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history_rounded),
            label: isRo ? 'Istoric' : 'History',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.group_outlined),
            activeIcon: const Icon(Icons.group_rounded),
            label: isRo ? 'Comunitate' : 'Community',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: isRo ? 'Profil' : 'Profile',
          ),
        ],
      ),
    );
  }
}

