import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/friend_model.dart';
import '../models/user_model.dart';
import '../providers/friend_provider.dart';
import '../providers/user_provider.dart';
import '../services/friend_service.dart';

class InviteFriendsSheet extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> roomSettings;

  const InviteFriendsSheet({
    super.key,
    required this.roomCode,
    required this.roomSettings,
  });

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  final _service = FriendService();
  final _db = FirebaseFirestore.instance;

  final Set<String> _invitedUids = {};
  final Set<String> _loadingUids = {};
  Map<String, DateTime?> _lastSeenMap = {};
  bool _loadingPresence = true;

  @override
  void initState() {
    super.initState();
    _loadPresence();
  }

  Future<void> _loadPresence() async {
    final friends = context.read<FriendProvider>().friends;
    if (friends.isEmpty) {
      if (mounted) setState(() => _loadingPresence = false);
      return;
    }
    final docs = await Future.wait(
      friends.map((f) => _db.collection('users').doc(f.friendUid).get()),
    );
    final map = <String, DateTime?>{};
    for (var i = 0; i < friends.length; i++) {
      final ts = docs[i].data()?['lastSeen'] as Timestamp?;
      map[friends[i].friendUid] = ts?.toDate();
    }
    if (mounted) setState(() { _lastSeenMap = map; _loadingPresence = false; });
  }

  bool _isOnline(String uid) {
    final seen = _lastSeenMap[uid];
    if (seen == null) return false;
    return DateTime.now().difference(seen).inMinutes < 5;
  }

  List<FriendModel> _sortedFriends(List<FriendModel> friends) {
    final sorted = [...friends];
    sorted.sort((a, b) {
      final aOn = _isOnline(a.friendUid);
      final bOn = _isOnline(b.friendUid);
      if (aOn && !bOn) return -1;
      if (!aOn && bOn) return 1;
      return a.friendDisplayName.compareTo(b.friendDisplayName);
    });
    return sorted;
  }

  Future<void> _invite(FriendModel friend, UserModel me) async {
    setState(() => _loadingUids.add(friend.friendUid));
    try {
      await _service.sendGameChallenge(
        me: me,
        targetUid: friend.friendUid,
        roomCode: widget.roomCode,
        roomSettings: widget.roomSettings,
      );
      if (mounted) {
        setState(() {
          _invitedUids.add(friend.friendUid);
          _loadingUids.remove(friend.friendUid);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUids.remove(friend.friendUid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final friends = context.watch<FriendProvider>().friends;
    final me = context.read<UserProvider>().user;
    final sorted = _sortedFriends(friends);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_add_rounded,
                          size: 18, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Undang Teman',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Kode room: ${widget.roomCode}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _loadingPresence
                    ? const Center(child: CircularProgressIndicator())
                    : friends.isEmpty
                        ? _EmptyState(colorScheme: colorScheme, textTheme: textTheme)
                        : ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom: bottomPad + 16,
                            ),
                            itemCount: sorted.length,
                            itemBuilder: (_, i) {
                              final friend = sorted[i];
                              final online = _isOnline(friend.friendUid);
                              final invited = _invitedUids.contains(friend.friendUid);
                              final loading = _loadingUids.contains(friend.friendUid);

                              return _FriendInviteTile(
                                friend: friend,
                                isOnline: online,
                                isInvited: invited,
                                isLoading: loading,
                                onInvite: me == null
                                    ? null
                                    : () => _invite(friend, me),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Friend tile ──────────────────────────────────────────────────────────────

class _FriendInviteTile extends StatelessWidget {
  final FriendModel friend;
  final bool isOnline;
  final bool isInvited;
  final bool isLoading;
  final VoidCallback? onInvite;

  const _FriendInviteTile({
    required this.friend,
    required this.isOnline,
    required this.isInvited,
    required this.isLoading,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial = friend.friendDisplayName.isNotEmpty
        ? friend.friendDisplayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF22C55E) : colorScheme.onSurface.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.friendDisplayName,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF22C55E)
                              : colorScheme.onSurface.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: textTheme.labelSmall?.copyWith(
                          color: isOnline
                              ? const Color(0xFF16A34A)
                              : colorScheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            if (isInvited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Terkirim',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              FilledButton.tonal(
                onPressed: onInvite,
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Undang',
                  style: textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _EmptyState({required this.colorScheme, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.group_off_rounded,
              size: 30,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Teman',
            style: textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tambah teman dulu agar bisa mengundang mereka ke room ini.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/friends/search');
            },
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Cari Teman'),
          ),
        ],
      ),
    );
  }
}
