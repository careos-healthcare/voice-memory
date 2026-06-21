import '../../product/consumer_copy_guard.dart';

/// Guards user-facing archive belief / timeline copy from overclaiming.
abstract final class ArchiveDisplayCopyGuard {
  static const bannedTerms = [
    'voicememory',
    'voice memory',
    'diagnosis',
    'diagnose',
    'disorder',
    'therapy',
    'therapist',
    'wellbeing',
    'your archive is learning',
    'this proves',
    'you always',
    'you never',
  ];

  static String? sanitize(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty || ConsumerCopyGuard.isSystemObservation(trimmed)) {
      return null;
    }
    final lower = trimmed.toLowerCase();
    for (final banned in bannedTerms) {
      if (lower.contains(banned)) return null;
    }
    return trimmed;
  }

  static bool passes(String text) => sanitize(text)?.isNotEmpty == true;

  static String displayOrEmpty(String? text) => sanitize(text) ?? '';
}
