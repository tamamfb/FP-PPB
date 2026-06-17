import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart'; // 👈 1. IMPORT SERVICE AUTHENTICATION MILIKMU
import '../utils/image_utils.dart';
import '../utils/level_utils.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final user = provider.user;
    final isLoading = provider.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TriLearn'),
        actions: [
          Consumer<FriendProvider>(
            builder: (context, fp, _) {
              final count = fp.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_rounded),
            onPressed: () => context.push('/friends'),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.blue),
            onPressed: () => context.push('/profile'),
          ),
          // 👈 2. PASANG FUNGSI LOGOUT PADA TOMBOL SETTINGS BAWAAN ORANG A
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.red,
            ), // Mengganti ikon ke logout agar user tahu fungsinya
            onPressed: () async {
              // Tampilkan dialog konfirmasi kecil sebelum keluar (Opsional tapi lebih rapi)
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar'),
                  content: const Text(
                    'Apakah kamu yakin ingin keluar dari TriLearn?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AuthService().logout(); // Panggil fungsi logout mesinmu
                // GoRouter di main.dart akan otomatis mendeteksi perubahan state menjadi null
                // dan langsung menendang user kembali ke halaman /login secara otomatis.
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserGreeting(user: user, isLoading: isLoading),
            const SizedBox(height: 28),
            Text(
              'Pilih Mode Bermain',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              icon: Icons.person_outline_rounded,
              title: 'Solo',
              subtitle: 'Latihan sendiri, pilih kategori favoritmu',
              color: colorScheme.primary,
              onTap: () => context.go('/solo/category'),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.group_outlined,
              title: 'Multiplayer',
              subtitle: 'Tantang temanmu secara real-time',
              color: colorScheme.secondary,
              onTap: () => context.go('/multi'),
            ),
            const SizedBox(height: 28),
            _DailyChallengeBanner(user: user),
          ],
        ),
      ),
    );
  }
}

class _UserGreeting extends StatelessWidget {
  final dynamic user;
  final bool isLoading;

  const _UserGreeting({this.user, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (user == null && isLoading) {
      return const _GreetingSkeleton();
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final name = user?.displayName;
    final photoURL = user?.photoURL as String?;
    final totalXp = (user?.totalXp as int?) ?? 0;
    final level = levelFromXp(totalXp);
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';

    return Row(
      children: [
        if (photoURL != null && photoURL.isNotEmpty)
          CircleAvatar(
            radius: 28,
            backgroundImage: photoImageProvider(photoURL),
          )
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primary,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name != null ? 'Halo, $name!' : 'Halo!',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Lv. $level',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Siap belajar hari ini?',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GreetingSkeleton extends StatelessWidget {
  const _GreetingSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Row(
      children: [
        CircleAvatar(radius: 28, backgroundColor: color),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeBanner extends StatelessWidget {
  final dynamic user;
  const _DailyChallengeBanner({this.user});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final done = user?.lastDailyDate == todayKey;

    return GestureDetector(
      onTap: () => context.push('/daily'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.8),
              colorScheme.secondary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.emoji_events_rounded,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tantangan Hari Ini',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    done
                        ? '+${user?.lastDailyScore ?? 0} XP • Selesai!'
                        : '10 soal • XP 2×',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
