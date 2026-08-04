class UserSession {
  const UserSession({
    required this.userId,
    required this.email,
    this.signedInAt,
  });

  final String userId;
  final String email;
  final DateTime? signedInAt;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : const <String, dynamic>{};
    final rawSignedInAt = json['signedInAt'];
    return UserSession(
      userId: _profileString(user['id']),
      email: _profileString(user['email']),
      signedInAt: rawSignedInAt is String
          ? DateTime.tryParse(rawSignedInAt)
          : null,
    );
  }
}

String _profileString(Object? value) => value is String ? value.trim() : '';
