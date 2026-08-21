import 'package:archiveme_mobile/core/json/json_converters.dart';

class UserSession {
  const UserSession({
    required this.userId,
    required this.email,
    this.signedInAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final user = JsonConverters.stringMapOrEmpty(json['user']);
    final signedInAtRaw = JsonConverters.nullableString(json['signedInAt']);
    return UserSession(
      userId: JsonConverters.stringOrEmpty(user['id']),
      email: JsonConverters.stringOrEmpty(user['email']),
      signedInAt:
          signedInAtRaw == null ? null : DateTime.tryParse(signedInAtRaw),
    );
  }

  final String userId;
  final String email;
  final DateTime? signedInAt;
}
