/// The four ownership promises ArchiveMe repeats wherever the archive can be
/// read, corrected, transcribed, or taken away.
///
/// Each line is held to shipped behaviour, not intent:
/// * originals are `AccessClass.userOwned`, so no entitlement can gate them;
/// * every interpretation can be corrected or hidden by the user;
/// * a recording can be transcribed by the local model or online, by choice;
/// * export and deletion are always available and never metered.
///
/// Surfaces reference these constants instead of restating them, so the wording
/// cannot drift apart between onboarding, privacy, and export.
abstract final class ArchiveOwnershipCopy {
  static const String recordingsStayYours = 'Your recordings stay yours.';

  static const String interpretationsCorrectable =
      "ArchiveMe's interpretations can be corrected or hidden.";

  static const String transcriptionChoice =
      'Choose on-device or online transcription.';

  static const String exportOrDeleteAnytime =
      'Export or delete your archive at any time.';

  /// Display order for every surface that shows the promises as a group.
  ///
  /// Four short lines is the whole of it: enough to be checkable, small enough
  /// that a first-use surface can carry it without becoming a privacy essay.
  static const List<String> all = [
    recordingsStayYours,
    interpretationsCorrectable,
    transcriptionChoice,
    exportOrDeleteAnytime,
  ];
}
