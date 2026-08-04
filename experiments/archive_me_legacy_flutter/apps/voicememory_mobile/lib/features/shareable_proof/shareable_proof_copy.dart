/// Generic, non-private share framing — never user transcripts or entry text.
abstract final class ShareableProofCopy {
  ShareableProofCopy._();

  static const title = 'Share the idea, not your archive';

  static const body =
      'ArchiveMe helped me notice what keeps returning — without sharing my private moments.';

  static const privacyWarning = 'Your saved moments are never included.';

  static const shareCta = 'Share non-private summary';

  static const templateKeepsReturning =
      'I started using ArchiveMe to notice what keeps returning. No daily journal required.';

  static const templateChatGptDifferentiation =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const templateTrackingTimeline =
      'I am tracking what appeared, what returned, and what changed — without sharing my private entries.';

  static const List<String> allVisibleStrings = [
    title,
    body,
    privacyWarning,
    shareCta,
    templateKeepsReturning,
    templateChatGptDifferentiation,
    templateTrackingTimeline,
  ];

  static const List<String> bannedPrivateMarkers = [
    'transcript',
    'entry_id',
    'journal_entry',
    'concreteObservation',
    'exactLanguagePattern',
    'Maria said',
    'divorce',
  ];

  static const List<String> bannedClinicalMarkers = [
    'therapy',
    'diagnosis',
    'medical treatment',
    'mental health score',
  ];

  static bool isSafeShareText(String text) {
    final lower = text.toLowerCase();
    for (final marker in bannedPrivateMarkers) {
      if (lower.contains(marker.toLowerCase())) return false;
    }
    for (final marker in bannedClinicalMarkers) {
      if (lower.contains(marker)) return false;
    }
    if (RegExp(r'\bentry[_-]?id\b', caseSensitive: false).hasMatch(text)) {
      return false;
    }
    return text.trim().isNotEmpty;
  }
}
