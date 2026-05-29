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
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return UserSession(
      userId: user['id'] as String? ?? '',
      email: user['email'] as String? ?? '',
      signedInAt: json['signedInAt'] != null
          ? DateTime.tryParse(json['signedInAt'] as String)
          : null,
    );
  }
}
