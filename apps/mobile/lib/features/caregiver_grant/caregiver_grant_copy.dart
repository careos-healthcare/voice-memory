/// Copy for the caregiver access grant flow.
///
/// Every sentence here is meant to be checkable against code. The bullets
/// under [canSee] describe exactly the four values on
/// `CaregiverDashboardSnapshot` that `CaregiverReadService` fills in
/// (`lib/features/caregiver/caregiver_read_service.dart:49`), and the
/// revocation wording matches what revoking actually does: the local set is
/// written first and unconditionally (`consent_revocation_store.dart`), then
/// `ServerConsentRevocationCoordinator` calls
/// `POST /api/coach/consent/revoke`, which the server's verify path consults
/// and fails closed on (`packages/shared/lib/server/consent-revocation-store.ts`).
/// A call that does not land is queued in `PendingConsentRevocationStore` and
/// retried, so the local half is immediate and the server half is eventually
/// consistent. That split is the reason [stopOnThisDevice] carries the only
/// "right away" on the screen and [stopReachesServer] carries the caveat.
///
/// Deliberately free of absolute qualifiers. `PrivacyCopyPolicy` treats
/// "never", "nothing", "always", "guaranteed" and friends as unsafe once they
/// share a clause with a privacy subject, and a consent screen is the last
/// place that should be leaning on them anyway.
abstract final class CaregiverGrantCopy {
  CaregiverGrantCopy._();

  // ——— Entry point ———

  static const String entryTitle = 'Grant Caregiver Access';

  /// Reads what the caregiver view actually shows.
  ///
  /// The brief asked for "help manage your care". There is no scheduling, no
  /// message path to a clinician, and no action a caregiver can take on the
  /// subject's behalf anywhere in this product — the caregiver surface is a
  /// read-only snapshot. "Manage your care" would promise a product that does
  /// not exist.
  static const String entrySubtitle =
      'Let a family member or someone you trust read short pieces of what '
      'you have saved.';

  static const String entryAction = 'Set up access';

  // ——— Disclosure ———

  static const String disclosureTitle = 'Before you share';

  static const String disclosureIntro =
      'Take a minute to read what this does. You can stop here and go back.';

  static const String canSeeHeading = 'What this does';

  static const String canSeeCount =
      'If you share journal moments, how many you have saved.';

  static const String canSeeRecent =
      'If you share journal moments, the opening words of your five most '
      'recent.';

  static const String canSeeTimeline =
      'If you share timeline and review summaries, the dates of your three '
      'most recent moments, with the opening words of each.';

  static const String canSeeAlert =
      'A short line about how many moments are in your archive is not shown '
      'in the caregiver view yet, even if you turn this on.';

  static const List<String> canSee = [
    canSeeCount,
    canSeeRecent,
    canSeeTimeline,
    canSeeAlert,
  ];

  // --- Permission toggles ---
  //
  // Mapped directly to CaregiverPermissions and CaregiverReadService
  // (lib/features/caregiver/caregiver_read_service.dart), not invented
  // independently of them. Journal gates the whole dashboard snapshot, not
  // just its own section -- if it's off, nothing else here shows either,
  // regardless of what else is on. Timeline and review summaries are two
  // separate consent choices that both have to be on for either to show
  // anything, so both toggles say so rather than implying they act alone.
  static const String permissionsHeading = 'Choose what to share';
  static const String journalToggleLabel = 'Journal moments';
  static const String journalToggleSubtitle =
      'How many moments you have saved, and the opening words of your five '
      'most recent. Turning this off hides everything else here too.';
  static const String proofTrailToggleLabel = 'Proof trail';
  static const String proofTrailToggleSubtitle =
      'Not yet shown in the caregiver view. Turning this on does not change '
      'what they see today.';
  static const String timelineToggleLabel = 'Timeline';
  static const String timelineToggleSubtitle =
      'The dates of your three most recent moments, with the opening words '
      'of each. Shown only when Review summaries below is also on.';
  static const String reviewSummariesToggleLabel = 'Review summaries';
  static const String reviewSummariesToggleSubtitle =
      'Shown only when Timeline above is also on.';

  static const String cannotHeading = 'What this does not include';

  static const String cannotFullText =
      'The caregiver view shows short pieces of text, not your full '
      'recordings.';

  static const String cannotAudio = 'It does not play your audio.';

  static const String cannotEdit =
      'It has no button to record, edit, or delete.';

  static const String cannotPatterns =
      'It does not show your patterns or reflections.';

  static const List<String> cannot = [
    cannotFullText,
    cannotAudio,
    cannotEdit,
    cannotPatterns,
  ];

  /// The limits above are now backed by a check on this device, which they
  /// were not when this caveat was first written. `CaregiverSessionGuard`
  /// refuses export, capture and audio playback from a caregiver session and
  /// refuses again when it cannot read the persona, and
  /// `CaregiverModeController.ensureReadAllowed` resolves every stream through
  /// `CaregiverPermissions.allowsStream` with no id exempted by name. What is
  /// still true, and what this string has to keep saying, is that the check
  /// runs on this device: there is no server-side caregiver read API for one
  /// to sit in front of.
  static const String cannotCaveat =
      'On this device these limits are checked, not just left out of the '
      'screens. The check runs here rather than on a server.';

  // ——— How to stop it ———

  static const String stopHeading = 'How to stop it';

  static const String stopOnThisDevice =
      'You can turn this off on this device whenever you want. The caregiver '
      'view here stops working right away.';

  /// The caregiver default TTL, declared once as
  /// `CAREGIVER_CONSENT_DEFAULT_TTL_MS` in
  /// `packages/shared/lib/consent/consent-token-ttl.ts:30`. This said 30 days
  /// until it was corrected: 30 is the coach default, declared a few lines
  /// below it in the same file. `caregiver_grant_copy_guard_test.dart` reads
  /// that constant and asserts this number against it, so the two cannot drift
  /// apart again on the strength of a comment.
  static const String stopPassLifetime =
      'The pass we hand out lasts up to 7 days.';

  /// The sentence the whole screen exists for.
  ///
  /// This used to say a handed-out pass kept working elsewhere until it ran
  /// out, which was true while revocation was local-only. It is not any more:
  /// every revoke path reaches `POST /api/coach/consent/revoke`, and the
  /// server refuses a revoked token. The second sentence is the part that is
  /// still not instant — an unsent revoke is queued and retried — and it is
  /// here rather than in a footnote because it is the bound on the promise the
  /// first sentence makes.
  static const String stopReachesServer =
      'Turning access off here also tells our server to stop honouring the '
      'pass. If you are offline, we finish that as soon as you reconnect.';

  /// Replaces "we do not have a way to end a pass early yet", which the
  /// server-side revocation list made false.
  static const String stopEndEarly =
      'You do not have to wait for a pass to run out.';

  static const List<String> stop = [
    stopOnThisDevice,
    stopPassLifetime,
    stopReachesServer,
    stopEndEarly,
  ];

  static const String disclosureCancel = 'Cancel';

  static const String disclosureContinue = 'I Understand, Let’s Continue';

  // ——— Consent form ———

  static const String formTitle = 'Who gets access?';

  /// True because the grant path sends an opaque id, not this text. See
  /// `CaregiverGrantContactStore` and `CaregiverGrantRequest.caregiverId`.
  static const String formIntro =
      'We keep this name and email on this device so you can tell your '
      'passes apart. We do not send them to our servers.';

  static const String nameLabel = 'Their name';

  static const String nameHint = 'For example, Sam Rivera';

  static const String nameError = 'Enter their name.';

  static const String emailLabel = 'Their email';

  static const String emailHint = 'For example, sam@example.com';

  static const String emailError =
      'Enter an email address that looks like sam@example.com';

  static const String thirdPartyNote =
      'This is another person’s information. Add it once they have agreed '
      'to that.';

  static const String formCancel = 'Cancel';

  static const String grantAction = 'Grant Access';

  static const String grantUnavailable =
      'We could not set up access just now. Please try again later.';

  /// Every user-visible string in this flow, for the copy guard test.
  static const List<String> all = [
    entryTitle,
    entrySubtitle,
    entryAction,
    disclosureTitle,
    disclosureIntro,
    canSeeHeading,
    ...canSee,
    cannotHeading,
    ...cannot,
    cannotCaveat,
    stopHeading,
    ...stop,
    disclosureCancel,
    disclosureContinue,
    formTitle,
    formIntro,
    nameLabel,
    nameHint,
    nameError,
    emailLabel,
    emailHint,
    emailError,
    thirdPartyNote,
    formCancel,
    grantAction,
    grantUnavailable,
  ];
}
