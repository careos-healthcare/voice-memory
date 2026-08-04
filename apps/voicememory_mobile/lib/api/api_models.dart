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

class CheckoutSession {
  const CheckoutSession({required this.url, this.sessionId});

  final String url;
  final String? sessionId;
}

class SubscriptionStatusResponse {
  const SubscriptionStatusResponse({
    required this.hasActiveSubscription,
    required this.subscriptionStatus,
    this.subscriptionEndDate,
  });

  factory SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatusResponse(
        hasActiveSubscription: json['hasActiveSubscription'] as bool? ?? false,
        subscriptionStatus: json['subscriptionStatus'] as String? ?? 'inactive',
        subscriptionEndDate: DateTime.tryParse(
          json['subscriptionEndDate'] as String? ?? '',
        ),
      );

  final bool hasActiveSubscription;
  final String subscriptionStatus;
  final DateTime? subscriptionEndDate;
}
