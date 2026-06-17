import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/friend_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/friend_service.dart';
import '../../utils/image_utils.dart';

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final _service = FriendService();
  final _controller = TextEditingController();
  List<UserModel> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _service.searchUsers(query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(UserModel target) async {
    final me = context.read<UserProvider>().user;
    if (me == null) return;
    final fp = context.read<FriendProvider>();
    await fp.sendRequest(me, target);
    if (!mounted) return;
    if (fp.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fp.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FriendProvider>();
    final friendUids = {for (final f in fp.friends) f.friendUid};
    final incomingUids = {for (final f in fp.incomingRequests) f.friendUid};
    final outgoingUids = {for (final f in fp.outgoingRequests) f.friendUid};

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cari username...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
          ),
          onChanged: _search,
        ),
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.isEmpty
                        ? 'Ketik username untuk mencari'
                        : 'Tidak ada pengguna ditemukan',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  itemBuilder: (context, i) {
                    final user = _results[i];
                    final isFriend = friendUids.contains(user.uid);
                    final isIncoming = incomingUids.contains(user.uid);
                    final isOutgoing = outgoingUids.contains(user.uid);

                    final Widget trailing;
                    if (isFriend) {
                      trailing = Chip(
                        label: const Text('Berteman'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    } else if (isIncoming) {
                      trailing = FilledButton.tonal(
                        onPressed: () => fp.acceptRequest(user.uid),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Terima'),
                      );
                    } else if (isOutgoing) {
                      trailing = Chip(
                        label: const Text('Terkirim'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    } else {
                      trailing = IconButton(
                        icon: const Icon(Icons.person_add_rounded),
                        tooltip: 'Tambah teman',
                        onPressed: () => _sendRequest(user),
                      );
                    }

                    final img = photoImageProvider(user.photoURL);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: img,
                        child: img == null
                            ? Text(user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text('@${user.username}'),
                      trailing: trailing,
                      onTap: () =>
                          context.push('/friends/profile/${user.uid}'),
                    );
                  },
                ),
    );
  }
}
