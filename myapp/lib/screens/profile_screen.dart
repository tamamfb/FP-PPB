import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/user_provider.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAndUploadImage(BuildContext context, String uid) async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (image == null) return;

    final file = File(image.path);

    final storage = StorageService();
    final url = await storage.uploadProfileImage(uid: uid, file: file);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'photoURL': url,
    });

    await context.read<UserProvider>().fetchCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final user = provider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// =========================
            /// PROFILE AVATAR
            /// =========================
            GestureDetector(
              onTap: () => _pickAndUploadImage(context, user.uid),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              user.username,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Text(user.email ?? "-"),

            const SizedBox(height: 20),

            /// =========================
            /// STATS CARD
            /// =========================
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text("Total XP: ${user.totalXp}"),
                    Text("Total Games: ${user.totalGames}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Game History",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            /// =========================
            /// HISTORY STREAM
            /// =========================
            Expanded(
              child: StreamBuilder(
                stream: userRef
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text("Belum ada history game"));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.gamepad),
                          title: Text("Score: ${data['skorAkhir']}"),
                          subtitle: Text(
                            "Benar: ${data['jumlahBenar']} / ${data['totalSoal']}",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
