class UserModel {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String? email;

  const UserModel({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.email,
  });
}
