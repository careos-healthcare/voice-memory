/// Canonical ArchiveMe privacy contract — single source for product and tests.
///
/// This documents what the app promises about user data. Consumer copy must stay
/// aligned with [PrivacyCopyPolicy]; behavioral code must enforce the rules
/// below rather than contradicting them.
abstract final class PrivacyContract {
  PrivacyContract._();

  /// Journal reflections and transcripts on device are encrypted at rest when
  /// encryption is enabled for the active account namespace.
  static const String journalEncryptedAtRest =
      'Journal content on this device is encrypted at rest.';

  /// Journal content is never uploaded unless the user uses a feature that
  /// requires remote transcription, sync, or analysis and has granted consent.
  static const String journalNotUploadedWithoutConsent =
      'Journal content is not sent to our servers unless you use cloud sync, '
      'transcription, or another feature that requires it and you have agreed.';

  /// Each signed-in account has physically separate local storage; switching
  /// accounts never reads or writes another account's namespace.
  static const String accountStorageIsolated =
      'Each account has its own local storage on this device; other accounts '
      'on the same device cannot access your reflections.';

  /// Deleting an account removes server-side data; local copy is a separate
  /// explicit step on the device.
  static const String deletionServerThenLocal =
      'Account deletion removes your server account and synced data first; '
      'deleting this device\'s local copy is a separate choice afterward.';

  /// Analytics and trial metrics must not include journal body text.
  static const String analyticsExcludeJournalBody =
      'Product analytics must not include journal body text or raw transcripts.';

  static const List<String> canonicalPromises = [
    journalEncryptedAtRest,
    journalNotUploadedWithoutConsent,
    accountStorageIsolated,
    deletionServerThenLocal,
    analyticsExcludeJournalBody,
  ];
}
