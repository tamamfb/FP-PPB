import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Leaderboard")),
      body: StreamBuilder(
        stream: provider.leaderboardStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text("Terjadi error saat load leaderboard"),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada data user"));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              final rank = index + 1;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text("#$rank", style: const TextStyle(fontSize: 12)),
                  ),

                  title: Text(
                    user.username,
                    style: TextStyle(
                      fontWeight: rank <= 3
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),

                  subtitle: Text("XP: ${user.totalXp}"),

                  trailing: rank == 1
                      ? const Icon(Icons.emoji_events, color: Colors.amber)
                      : rank == 2
                      ? const Icon(Icons.emoji_events, color: Colors.grey)
                      : rank == 3
                      ? const Icon(Icons.emoji_events, color: Colors.brown)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
