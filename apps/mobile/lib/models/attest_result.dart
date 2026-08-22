class AttestResult {
  const AttestResult._({this.token, this.expiresInSeconds, this.sessionUserId});

  factory AttestResult.capture({
    required String token,
    required int expiresInSeconds,
  }) => AttestResult._(token: token, expiresInSeconds: expiresInSeconds);

  factory AttestResult.session({required String userId}) =>
      AttestResult._(sessionUserId: userId);

  final String? token;
  final int? expiresInSeconds;
  final String? sessionUserId;

  bool get isSession => sessionUserId != null;
}