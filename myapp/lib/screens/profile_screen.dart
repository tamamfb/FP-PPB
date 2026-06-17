import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:go_router/go_router.dart';

import '../providers/user_provider.dart';
import '../utils/image_utils.dart';
import '../utils/level_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _enterEditMode(user) {
    _usernameController.text = user.username;
    _displayNameController.text = user.displayName;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  Future<void> _save(BuildContext context, String uid) async {
    setState(() => _isSaving = true);

    final error = await context.read<UserProvider>().updateProfile(
      username: _usernameController.text,
      displayName: _displayNameController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      setState(() => _isEditing = false);
    }
  }

  Future<void> _pickImage(BuildContext context, String uid, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'photoURL': base64String});

    if (!mounted) return;
    await context.read<UserProvider>().fetchCurrentUser();
  }

  void _showImageSourceSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, uid, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, uid, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final user = provider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
        actions: _isEditing
            ? [
                TextButton(
                  onPressed: _isSaving ? null : _cancelEdit,
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isSaving ? null : () => _save(context, user.uid),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _enterEditMode(user),
                ),
              ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// PROFILE AVATAR
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: photoImageProvider(user.photoURL),
                  child: photoImageProvider(user.photoURL) == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImageSourceSheet(context, user.uid),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            /// USERNAME
            if (_isEditing)
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'Must be unique. Used to log in.',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Text(
                '@${user.username}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 12),

            /// DISPLAY NAME
            if (_isEditing)
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'Shown to other players in multiplayer.',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Text(user.displayName),

            const SizedBox(height: 8),

            Text(user.email ?? '-', style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            /// STATS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Level ${levelFromXp(user.totalXp)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${user.totalXp} XP total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: levelProgress(user.totalXp),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${xpIntoLevel(user.totalXp)} / ${xpNeededForLevel(user.totalXp)} XP ke level berikutnya',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                    const Divider(height: 24),
                    Text('Total Games: ${user.totalGames}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Game History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            /// HISTORY STREAM
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('Belum ada history game'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      final isMulti = data['mode'] == 'multiplayer';
                      return Card(
                        child: ListTile(
                          leading: Icon(isMulti ? Icons.group_rounded : Icons.person_rounded),
                          title: Text('Score: ${data['skorAkhir'] ?? 0}'),
                          subtitle: Text(
                            isMulti
                                ? 'Multiplayer'
                                : 'Benar: ${data['jumlahBenar'] ?? '-'} / ${data['totalSoal'] ?? '-'}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/profile/history', extra: data),
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
