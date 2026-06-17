import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/friend_model.dart';
import '../../providers/friend_provider.dart';
import '../../utils/image_utils.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final incoming = context.watch<FriendProvider>().incomingRequests.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teman'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_search_rounded),
              tooltip: 'Cari teman',
              onPressed: () => context.push('/friends/search'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Teman'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Permintaan'),
                    if (incoming > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$incoming',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsTab(),
            _RequestsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Friends tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendProvider>().friends;

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 64,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada teman',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.push('/friends/search'),
              child: const Text('Cari teman'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: friends.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, i) => _FriendTile(friend: friends[i]),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendModel friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final img = photoImageProvider(friend.friendPhotoURL);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: img,
        child: img == null
            ? Text(friend.friendDisplayName.isNotEmpty
                ? friend.friendDisplayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(friend.friendDisplayName),
      subtitle: Text('@${friend.friendUsername}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/friends/profile/${friend.friendUid}'),
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<FriendProvider>().incomingRequests;

    if (requests.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada permintaan pertemanan',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, i) => _RequestTile(friend: requests[i]),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendModel friend;
  const _RequestTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final img = photoImageProvider(friend.friendPhotoURL);
    final fp = context.read<FriendProvider>();

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: img,
        child: img == null
            ? Text(friend.friendDisplayName.isNotEmpty
                ? friend.friendDisplayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(friend.friendDisplayName),
      subtitle: Text('@${friend.friendUsername}'),
      onTap: () => context.push('/friends/profile/${friend.friendUid}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.green),
            tooltip: 'Terima',
            onPressed: () => fp.acceptRequest(friend.friendUid),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: Theme.of(context).colorScheme.error),
            tooltip: 'Tolak',
            onPressed: () => fp.declineRequest(friend.friendUid),
          ),
        ],
      ),
    );
  }
}
