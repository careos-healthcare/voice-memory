/// What actually happened when a caregiver/coach grant was revoked.
///
/// [localRevoked] is the part the user is entitled to rely on: it is true as
/// soon as the device has stopped honouring the grant, network or not.
/// [serverConfirmed] says whether the server has also stopped honouring the
/// already-issued token; when it has not, [queuedForRetry] says the device
/// still owes that call and will retry it.
class ConsentRevocationOutcome {
  const ConsentRevocationOutcome({
    required this.localRevoked,
    required this.serverConfirmed,
    required this.queuedForRetry,
    this.failureCode,
  });

  /// Nothing was revoked — there was no store to revoke against.
  static const notAttempted = ConsentRevocationOutcome(
    localRevoked: false,
    serverConfirmed: false,
    queuedForRetry: false,
  );

  final bool localRevoked;
  final bool serverConfirmed;
  final bool queuedForRetry;

  /// Short, non-identifying code from `ConsentRevocationFailureCode`, or null.
  final String? failureCode;

  /// True when the device has revoked but the server has not confirmed yet —
  /// the "revoked here, still syncing" state a surface can report.
  bool get isLocalOnly => localRevoked && !serverConfirmed;
}
