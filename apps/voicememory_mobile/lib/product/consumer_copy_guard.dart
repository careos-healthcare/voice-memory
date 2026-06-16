/// Filters system/cloud boilerplate from user-visible copy.
abstract class ConsumerCopyGuard {
  ConsumerCopyGuard._();

  static const _blockedObservationFragments = [
    'saved on this device',
    'cloud processing',
    'cloud analysis',
    'cloud sync',
    'processing pending',
    'sync is unavailable',
    'sync unavailable',
    'never synced',
    'saved locally',
    '[draft]',
    'transcribe when connected',
  ];

  static bool isSystemObservation(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (lower == 'saved privately on this device.' ||
        lower == 'saved privately on this device') {
      return true;
    }
    for (final fragment in _blockedObservationFragments) {
      if (lower.contains(fragment)) return true;
    }
    return lower.startsWith('the archive') ||
        lower.startsWith('saved on this device');
  }

  static bool isForbiddenCloudCopy(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final fragment in _blockedObservationFragments) {
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
