import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/friend_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FriendProvider>();
    final notifs = fp.notifications;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada notifikasi',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _NotifTile(
                notif: notifs[i],
                myUid: myUid,
              ),
            ),
    );
  }
}

String _settingsSummary(NotificationModel notif) {
  final s = notif.roomSettings;
  if (s == null) return 'Kode Room: ${notif.roomCode ?? '-'}';
  final cat = s['categoryName'] as String? ?? 'Semua Kategori';
  final diff = switch (s['difficulty'] as String? ?? 'any') {
    'easy' => 'Mudah',
    'medium' => 'Sedang',
    'hard' => 'Sulit',
    _ => 'Semua',
  };
  final type = switch (s['type'] as String? ?? 'any') {
    'multiple' => 'Pilihan Ganda',
    'boolean' => 'Benar/Salah',
    _ => 'Semua Tipe',
  };
  final amt = s['amount'] as int? ?? 10;
  return '$cat · $diff · $type · $amt soal';
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final String myUid;
  const _NotifTile({required this.notif, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final fp = context.read<FriendProvider>();

    if (notif.type == 'friend_request') {
      return ListTile(
        leading: CircleAvatar(
          child: Text(
            notif.fromDisplayName.isNotEmpty
                ? notif.fromDisplayName[0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(notif.fromDisplayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Ingin berteman denganmu'),
        onTap: () => context.push('/friends/profile/${notif.fromUid}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.green),
              tooltip: 'Terima',
              onPressed: () => fp.acceptRequest(notif.fromUid),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Tolak',
              onPressed: () => fp.declineRequest(notif.fromUid),
            ),
          ],
        ),
      );
    }

    // game_challenge
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        child: Icon(
          Icons.sports_esports_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        '${notif.fromDisplayName} mengajakmu bermain!',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_settingsSummary(notif)),
      onTap: () => context.push('/challenge/invitation', extra: notif),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: () =>
                context.push('/challenge/invitation', extra: notif),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Lihat'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Abaikan',
            onPressed: () => fp.deleteNotification(myUid, notif.id),
          ),
        ],
      ),
    );
  }
}
