import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/friend_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/image_utils.dart';
import '../../utils/level_utils.dart';

class FriendProfileScreen extends StatefulWidget {
  final String uid;
  const FriendProfileScreen({super.key, required this.uid});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  UserModel? _profile;
  // null | 'pending_out' | 'pending_in' | 'accepted'
  String? _friendStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final db = FirebaseFirestore.instance;

    final futures = await Future.wait([
      db.collection('users').doc(widget.uid).get(),
      if (myUid != null)
        db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(widget.uid)
            .get(),
    ]);

    final userDoc = futures[0];
    final friendDoc = futures.length > 1 ? futures[1] : null;

    if (!mounted) return;

    UserModel? profile;
    if (userDoc.exists && userDoc.data() != null) {
      profile = UserModel.fromFirestore(userDoc.data()!);
    }

    String? status;
    if (friendDoc != null && friendDoc.exists) {
      final data = friendDoc.data()!;
      final s = data['status'] as String?;
      final initiatedBy = data['initiatedBy'] as String?;
      if (s == 'accepted') {
        status = 'accepted';
      } else if (s == 'pending') {
        status = initiatedBy == myUid ? 'pending_out' : 'pending_in';
      }
    }

    setState(() {
      _profile = profile;
      _friendStatus = status;
      _loading = false;
    });
  }

  Future<void> _sendRequest() async {
    final me = context.read<UserProvider>().user;
    if (me == null || _profile == null) return;
    final fp = context.read<FriendProvider>();
    await fp.sendRequest(me, _profile!);
    if (!mounted) return;
    if (fp.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(fp.error!)));
    } else {
      setState(() => _friendStatus = 'pending_out');
    }
  }

  Future<void> _acceptRequest() async {
    await context.read<FriendProvider>().acceptRequest(widget.uid);
    if (mounted) setState(() => _friendStatus = 'accepted');
  }

  Future<void> _declineRequest() async {
    await context.read<FriendProvider>().declineRequest(widget.uid);
    if (mounted) setState(() => _friendStatus = null);
  }

  Future<void> _unfriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus teman?'),
        content:
            Text('Kamu akan menghapus ${_profile?.displayName} dari daftar teman.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<FriendProvider>().unfriend(widget.uid);
    if (mounted) setState(() => _friendStatus = null);
  }

  void _challenge() {
    context.push('/multi/create', extra: widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Pengguna tidak ditemukan.')),
      );
    }

    final profile = _profile!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final img = photoImageProvider(profile.photoURL);
    final level = levelFromXp(profile.totalXp);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.displayName),
        actions: [
          if (_friendStatus == 'accepted')
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Hapus teman',
              onPressed: _unfriend,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 52,
              backgroundImage: img,
              child: img == null
                  ? Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 36),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Level $level',
                style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Total XP',
                    value: '${profile.totalXp}',
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.videogame_asset_rounded,
                    label: 'Total Game',
                    value: '${profile.totalGames}',
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_friendStatus == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _challenge,
          icon: const Icon(Icons.sports_esports_rounded),
          label: const Text('Tantang Bermain'),
        ),
      );
    }

    if (_friendStatus == 'pending_out') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty_rounded),
          label: const Text('Permintaan Terkirim'),
        ),
      );
    }

    if (_friendStatus == 'pending_in') {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _acceptRequest,
              child: const Text('Terima'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _declineRequest,
              child: const Text('Tolak'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _sendRequest,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Teman'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
