import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/friend_model.dart';
import '../../providers/friends_provider.dart';
import '../../providers/locale_provider.dart';
import 'friend_profile_screen.dart';

/// Manage friends: search, accept invites, view friend list.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results =
        await ref.read(friendsProvider.notifier).searchUsers(query);
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final isRo = ref.watch(isRomanianProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRo ? 'Prieteni' : 'Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(friendsProvider.notifier).load(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Search bar ─────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: isRo
                  ? 'Caută un ciclist după nume...'
                  : 'Search cyclists by name...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          // ── Search results ─────────────────────────────────────
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isRo ? 'Rezultate căutare' : 'Search results',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.subtleText),
            ),
            const SizedBox(height: 8),
            ...(_searchResults.map((r) => _SearchResultTile(
                  userId: r['id'] as String,
                  name: r['name'] as String? ?? 'Cyclist',
                  email: r['email'] as String? ?? '',
                  bicycleType: r['bicycle_type'] as String?,
                  currentFriends: friends,
                  isRo: isRo,
                ))),
          ] else if (_searchCtrl.text.length >= 2) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                isRo ? 'Niciun rezultat găsit.' : 'No results found.',
                style: const TextStyle(color: AppTheme.subtleText),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Pending received invites ───────────────────────────
          if (friends.pendingReceived.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.mark_email_unread_rounded,
              label: isRo
                  ? 'Cereri primite (${friends.pendingReceived.length})'
                  : 'Pending invites (${friends.pendingReceived.length})',
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: 8),
            ...friends.pendingReceived.map((f) => _InviteReceivedTile(
                  friend: f,
                  isRo: isRo,
                )),
            const SizedBox(height: 16),
          ],

          // ── Pending sent invites ───────────────────────────────
          if (friends.pendingSent.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.schedule_send_rounded,
              label: isRo
                  ? 'Cereri trimise (${friends.pendingSent.length})'
                  : 'Sent requests (${friends.pendingSent.length})',
              color: AppTheme.subtleText,
            ),
            const SizedBox(height: 8),
            ...friends.pendingSent.map((f) => _SentRequestTile(
                  friend: f,
                  isRo: isRo,
                )),
            const SizedBox(height: 16),
          ],

          // ── Friend list ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.people_rounded,
            label: isRo
                ? 'Prietenii tăi (${friends.friends.length})'
                : 'Your friends (${friends.friends.length})',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 8),
          if (friends.loading)
            const Center(child: CircularProgressIndicator())
          else if (friends.friends.isEmpty)
            _EmptyFriends(isRo: isRo)
          else
            ...friends.friends.map((f) => _FriendTile(
                  friend: f,
                  isRo: isRo,
                )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Search result tile ───────────────────────────────────────────────────────

class _SearchResultTile extends ConsumerWidget {
  final String userId;
  final String name;
  final String email;
  final String? bicycleType;
  final FriendsState currentFriends;
  final bool isRo;

  const _SearchResultTile({
    required this.userId,
    required this.name,
    required this.email,
    required this.bicycleType,
    required this.currentFriends,
    required this.isRo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alreadyFriend = currentFriends.friends.any((f) => f.userId == userId);
    final sentRequest =
        currentFriends.pendingSent.any((f) => f.userId == userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _Avatar(initials: _initials(name)),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(bicycleType ?? email,
            style: const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
        trailing: alreadyFriend
            ? const Icon(Icons.check_circle_rounded,
                color: AppTheme.successColor)
            : sentRequest
                ? Text(isRo ? 'Trimis' : 'Sent',
                    style: const TextStyle(
                        color: AppTheme.subtleText, fontSize: 12))
                : FilledButton.tonal(
                    onPressed: () =>
                        ref.read(friendsProvider.notifier).sendRequest(userId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: Size.zero,
                    ),
                    child: Text(isRo ? 'Adaugă' : 'Add'),
                  ),
      ),
    );
  }
}

// ─── Received invite tile ─────────────────────────────────────────────────────

class _InviteReceivedTile extends ConsumerWidget {
  final FriendModel friend;
  final bool isRo;

  const _InviteReceivedTile({required this.friend, required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.warningColor.withAlpha(10),
      child: ListTile(
        leading: _Avatar(initials: friend.initials),
        title: Text(friend.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          isRo ? 'Ți-a trimis o cerere de prietenie' : 'Sent you a friend request',
          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppTheme.successColor),
              onPressed: () => ref
                  .read(friendsProvider.notifier)
                  .acceptRequest(friend.userId),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppTheme.errorColor),
              onPressed: () => ref
                  .read(friendsProvider.notifier)
                  .declineRequest(friend.userId),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sent request tile ────────────────────────────────────────────────────────

class _SentRequestTile extends StatelessWidget {
  final FriendModel friend;
  final bool isRo;

  const _SentRequestTile({required this.friend, required this.isRo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _Avatar(initials: friend.initials, opacity: 0.5),
        title: Text(friend.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          isRo ? 'În așteptare...' : 'Waiting for response...',
          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.subtleText.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isRo ? 'În așteptare' : 'Pending',
            style: const TextStyle(fontSize: 11, color: AppTheme.subtleText),
          ),
        ),
      ),
    );
  }
}

// ─── Friend tile (accepted) ───────────────────────────────────────────────────

class _FriendTile extends ConsumerWidget {
  final FriendModel friend;
  final bool isRo;

  const _FriendTile({required this.friend, required this.isRo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FriendProfileScreen(friend: friend, isRo: isRo),
          ),
        ),
        leading: _Avatar(initials: friend.initials),
        title: Text(friend.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${friend.totalRides} ${isRo ? 'curse' : 'rides'}  ·  '
          '${friend.totalKm.toStringAsFixed(1)} km',
          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Achievement badge count
            if (friend.unlockedAchievementIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🏅 ${friend.unlockedAchievementIds.length}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.subtleText),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyFriends extends StatelessWidget {
  final bool isRo;

  const _EmptyFriends({required this.isRo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 56, color: AppTheme.dividerColor),
          const SizedBox(height: 12),
          Text(
            isRo
                ? 'Niciun prieten încă.\nCaută un ciclist pentru a-l adăuga!'
                : 'No friends yet.\nSearch for a cyclist to add!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.subtleText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Shared avatar widget ─────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  final double opacity;

  const _Avatar({required this.initials, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CircleAvatar(
        backgroundColor: AppTheme.primary,
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}
