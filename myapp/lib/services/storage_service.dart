import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref().child('profile_pictures/$uid.jpg');

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }
}
