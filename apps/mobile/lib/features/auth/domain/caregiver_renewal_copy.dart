/// Plain-language copy for continuing a caregiver access window.
///
/// Kept apart from `CaregiverAccessCopy` because almost every string here is
/// parameterised. A renewal prompt has to name the person, the day the current
/// window ends and the day the new one does, or it is asking the archive owner
/// to confirm something they have no way to check.
///
/// Three rules the surrounding caregiver copy already follows. Each one bites
/// harder here, because this is the moment the owner is deciding whether an
/// arrangement is safe to continue rather than reading about one.
///
/// - Nothing in this file says what a caregiver can or cannot see. Those
///   limits are a check this app runs on this device, and there is no
///   server-side caregiver read API for one to sit in front of. Renewal copy
///   that described the scope would lend that claim the weight of the one
///   thing next to it that the server does act on.
/// - Ending access is scoped to this device, in the same words
///   `CaregiverAccessCopy.revokeConfirmBody` already uses. The server's
///   `verify` route consults no revocation list, so a token already issued
///   keeps verifying until its own expiry. An unscoped "you can end it sooner"
///   would be a promise this app cannot keep.
/// - The window length is never hard-coded. This device is not told how long a
///   successor will last until the server answers, so the prompt quotes the
///   length of the window the owner can already see on the row, and only the
///   confirmation names a date — the one the server actually returned.
abstract final class CaregiverRenewalCopy {
  CaregiverRenewalCopy._();

  static const renewAccessCta = 'Renew';
  static const cancelCta = 'Not now';

  static String confirmTitle({required String partyLabel, required int days}) =>
      "Continue $partyLabel's access for another ${_dayCount(days)}?";

  static String confirmBody({required String endsOn, required int days}) =>
      'This access ends on $endsOn. Confirming starts a new '
      '${_hyphenatedDays(days)} window. You can end it on this device from '
      'this screen at any time.';

  static String confirmCta(int days) =>
      days == 1 ? 'Confirm for 1 more day' : 'Confirm for $days more days';

  static String successSnack(String endsOn) => 'Access continues until $endsOn.';

  /// Covers both settled refusals, so it names neither.
  ///
  /// `ConsentRenewalOutcome.shouldOfferFreshGrant` is true for `grant_expired`
  /// and `not_renewable` alike, and only the first of those is a window that
  /// closed. A grant this device holds no token for, or one already withdrawn,
  /// reaches here too, and telling that owner their window has closed would be
  /// a guess dressed as a fact.
  static const freshGrantSnack =
      "This can't be continued as it stands. To carry on, grant access again — "
      "you'll see the scope before it starts.";

  /// Every refusal that is not settled and not a partial result.
  ///
  /// True of all of them: the server either replaces a grant or leaves it
  /// alone, so nothing about the current window has moved.
  static const unavailableSnack =
      "We couldn't complete this just now. The current window is unchanged.";

  /// A successor exists but this device was not told the predecessor ended.
  static const unsettledSnack =
      "This didn't finish. Check the access list before relying on it.";

  static String _dayCount(int days) => days == 1 ? '1 day' : '$days days';

  static String _hyphenatedDays(int days) =>
      days == 1 ? '1-day' : '$days-day';
}
