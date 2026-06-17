import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/friend_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/user_provider.dart';

class ChallengeInvitationScreen extends StatefulWidget {
  final NotificationModel notif;
  const ChallengeInvitationScreen({super.key, required this.notif});

  @override
  State<ChallengeInvitationScreen> createState() =>
      _ChallengeInvitationScreenState();
}

class _ChallengeInvitationScreenState
    extends State<ChallengeInvitationScreen> {
  final _displayNameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text =
        context.read<UserProvider>().user?.displayName ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tampilan tidak boleh kosong.')),
      );
      return;
    }

    final user = context.read<UserModel?>();
    final roomCode = widget.notif.roomCode;
    if (user == null || roomCode == null) return;

    final fp = context.read<FriendProvider>();
    final mp = context.read<MultiplayerProvider>();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() => _loading = true);

    await fp.deleteNotification(myUid, widget.notif.id);

    await mp.joinRoom(
      roomCode: roomCode,
      uid: user.uid,
      displayName: displayName,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (mp.status == MultiplayerStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mp.error ?? 'Gagal bergabung ke room.')),
      );
    } else {
      context.go('/multi/game');
    }
  }

  Future<void> _decline() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await context
        .read<FriendProvider>()
        .deleteNotification(myUid, widget.notif.id);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notif;
    final s = notif.roomSettings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tantangan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.sports_esports_rounded,
                  size: 64, color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                '${notif.fromDisplayName} mengajakmu bermain!',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    if (s != null) ...[
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value:
                            s['categoryName'] as String? ?? 'Semua Kategori',
                      ),
                      _DetailRow(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: 'Kesulitan',
                        value: _difficultyLabel(
                            s['difficulty'] as String? ?? 'any'),
                      ),
                      _DetailRow(
                        icon: Icons.quiz_outlined,
                        label: 'Tipe Soal',
                        value:
                            _typeLabel(s['type'] as String? ?? 'any'),
                      ),
                      _DetailRow(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Jumlah Soal',
                        value: '${s['amount'] ?? 10} soal',
                      ),
                    ] else ...[
                      _DetailRow(
                        icon: Icons.meeting_room_outlined,
                        label: 'Kode Room',
                        value: notif.roomCode ?? '-',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Tampilan',
                  hintText: 'Nama kamu di room ini',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _decline,
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _join,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Gabung!'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

String _difficultyLabel(String d) => switch (d) {
      'easy' => 'Mudah',
      'medium' => 'Sedang',
      'hard' => 'Sulit',
      _ => 'Semua',
    };

String _typeLabel(String t) => switch (t) {
      'multiple' => 'Pilihan Ganda',
      'boolean' => 'Benar/Salah',
      _ => 'Semua Tipe',
    };

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
