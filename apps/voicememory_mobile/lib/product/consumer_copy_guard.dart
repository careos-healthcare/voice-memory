import '../features/archive_evidence/archive_pattern_copy_guard.dart';

/// Filters system/cloud boilerplate from user-visible copy.
abstract class ConsumerCopyGuard {
  ConsumerCopyGuard._();

  static bool isSystemObservation(String text) =>
      ArchivePatternCopyGuard.isBlockedPatternText(text);

  static bool isForbiddenCloudCopy(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final fragment in ArchivePatternCopyGuard.blockedFragments) {
      if (lower.contains(fragment)) return true;
    }
    return false;
  }

  static String? userFacingObservation(String? text) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty || isSystemObservation(trimmed)) return null;
    return trimmed;
  }

  static String? userFacingSyncNote(String? note) {
    final trimmed = note?.trim() ?? '';
    if (trimmed.isEmpty || isForbiddenCloudCopy(trimmed)) return null;
    return trimmed;
  }

  static List<String> userFacingChips(Iterable<String> chips) {
    return chips
        .map((c) => c.trim())
        .where(
          (c) =>
              c.isNotEmpty &&
              !isSystemObservation(c) &&
              !isForbiddenCloudCopy(c),
        )
        .toList();
  }
}
