class UserModel {
  final String uid;
  final String displayName;
  final String username;
  final String? photoURL;
  final String? email;
  final int totalXp;
  final int totalGames;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoURL,
    this.email,
    this.totalXp = 0,
    this.totalGames = 0,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? data['username'] ?? '',
      username: data['username'] ?? '',
      photoURL: data['photoURL'],
      email: data['email'],
      totalXp: data['total_xp'] ?? 0,
      totalGames: data['total_games'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'photoURL': photoURL,
      'email': email,
      'total_xp': totalXp,
      'total_games': totalGames,
    };
  }
}
