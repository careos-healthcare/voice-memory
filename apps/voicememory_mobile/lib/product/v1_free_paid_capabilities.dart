/// Authoritative free-vs-paid capability table for V1 launch.
///
/// Used by entitlement checks, paywall copy, settings, and tests.
/// Privacy, deletion, export, corrections, and original content stay free.
abstract final class V1FreePaidCapabilities {
  V1FreePaidCapabilities._();

  static const freeCapabilities = [
    V1Capability.voiceCapture,
    V1Capability.textCapture,
    V1Capability.encryptedLocalStorage,
    V1Capability.originalArchive,
    V1Capability.essentialSearch,
    V1Capability.entryEditDelete,
    V1Capability.export,
    V1Capability.privacySecurityControls,
    V1Capability.correctionsAndSuppression,
    V1Capability.basicEvidenceTransparency,
    V1Capability.accountDeletion,
  ];

  static const paidCapabilities = [
    V1Capability.deeperHistory,
    V1Capability.longerTimeRangeComparisons,
    V1Capability.richerVerifiedChangeHistory,
    V1Capability.advancedArchiveSearchFiltering,
    V1Capability.secureBackupSync,
  ];

  static bool isFree(V1Capability capability) =>
      freeCapabilities.contains(capability);

  static bool isPaid(V1Capability capability) =>
      paidCapabilities.contains(capability);

  static bool requiresPro(V1Capability capability) => isPaid(capability);
}

enum V1Capability {
  voiceCapture,
  textCapture,
  encryptedLocalStorage,
  originalArchive,
  essentialSearch,
  entryEditDelete,
  export,
  privacySecurityControls,
  correctionsAndSuppression,
  basicEvidenceTransparency,
  accountDeletion,
  deeperHistory,
  longerTimeRangeComparisons,
  richerVerifiedChangeHistory,
  advancedArchiveSearchFiltering,
  secureBackupSync,
}
