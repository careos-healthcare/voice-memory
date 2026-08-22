/// What actually happened when the archive owner asked to renew a caregiver
/// grant.
///
/// Shaped after `ConsentRevocationOutcome`, and for the same reason: a surface
/// has to be able to say something true after a partial result, without
/// throwing and without inventing a reassurance. Three rules carried over
/// unchanged:
///
/// - it never throws, so a renewal that fails cannot take a screen down with
///   it;
/// - [failureCode] is a closed set of short, non-identifying codes from
///   `ConsentRenewalFailureCode`, because an outcome can be written to plain
///   preferences and a server message or a caregiver's name has no business
///   there;
/// - it separates what the device knows from what the server confirmed.
///
/// One rule is new, and it is the difference between the two. Revocation has a
/// meaningful local-only state: the device stops honouring a grant right away
/// and owes the server a call it will retry. Renewal has no such state. A
/// device cannot mint a credential the server will honour, and it must not
/// retry a renewal later on its own — a renewal that lands at a moment the
/// owner was not asked is the scheduled extension this design rules out. So
/// [renewed] is true only when the server confirmed, and there is no
/// `queuedForRetry`.
class ConsentRenewalOutcome {
  const ConsentRenewalOutcome({
    required this.renewed,
    required this.previousGrantEnded,
    this.newGrantId,
    this.newExpiresAt,
    this.failureCode,
  });

  /// A renewal the server declined or could not complete.
  ///
  /// The previous grant is reported as untouched, which is what every refusal
  /// path on the server guarantees: it either replaces the grant or leaves it
  /// alone.
  factory ConsentRenewalOutcome.refused(String failureCode) =>
      ConsentRenewalOutcome(
        renewed: false,
        previousGrantEnded: false,
        failureCode: failureCode,
      );

  /// Nothing was asked for — there was no grant or no client to ask.
  static const notAttempted = ConsentRenewalOutcome(
    renewed: false,
    previousGrantEnded: false,
  );

  /// The server confirmed a successor grant and withdrew the previous one.
  final bool renewed;

  /// The server confirmed the previous grant is on its revocation list.
  ///
  /// Tracked separately from [renewed] so a caller can tell the difference
  /// between "nothing changed" and the state that would need attention: a
  /// successor that exists while the predecessor's fate is unknown. Nothing on
  /// the server produces that today, and a client that sees it should treat
  /// the arrangement as unsettled rather than renewed.
  final bool previousGrantEnded;

  /// Identifier of the successor grant, when there is one.
  final String? newGrantId;

  /// When the successor's window ends. Safe to store: a timestamp, not a name.
  final DateTime? newExpiresAt;

  /// Short, non-identifying code from `ConsentRenewalFailureCode`, or null.
  final String? failureCode;

  /// True when a successor exists but the previous grant was not confirmed
  /// withdrawn — the one state a surface should describe as unfinished.
  bool get isUnsettled => renewed && !previousGrantEnded;

  /// True when the honest next step is to grant access again rather than retry.
  ///
  /// A window that has already closed, and a caller the grant does not name as
  /// its owner, are both settled answers. Retrying either reaches the same
  /// place.
  bool get shouldOfferFreshGrant =>
      failureCode == 'grant_expired' || failureCode == 'not_renewable';
}
