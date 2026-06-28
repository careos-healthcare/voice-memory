/// Hard denylist for operational/system copy that must never surface as
/// archive patterns, beliefs, quiet patterns, or evidence summaries.
abstract final class ArchivePatternCopyGuard {
  ArchivePatternCopyGuard._();

  static const blockedFragments = [
    'saved privately',
    'saved on this device',
    'private on this device',
    'encrypted',
    'local only',
    'data stays',
    'restore purchases',
    'subscription',
    'privacy',
    'archive review is ready',
    'record moment',
    'type instead',
    'save one moment',
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
    'your weekly review is ready',
    'review changes',
    'view evidence map',
    'mark as seen',
    'longer-term change history',
    'add one more moment',
    'ready to record',
    'log pressure moment',
  ];

  static bool isBlockedPatternText(String? text) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return true;

    final lower = trimmed.toLowerCase();
    for (final fragment in blockedFragments) {
      if (lower.contains(fragment)) return true;
    }

    // Subscription/marketing "Pro" — whole word only so user reflections stay intact.
    if (RegExp(r'\bpro\b').hasMatch(lower)) return true;

    return lower.startsWith('the archive') ||
        lower.startsWith('saved on this device');
  }

  static bool isValidPatternCandidate(String? text) =>
      !isBlockedPatternText(text);

  static String? sanitizePatternText(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return isBlockedPatternText(trimmed) ? null : trimmed;
  }

  static List<String> filterCandidates(Iterable<String> candidates) {
    return candidates
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && isValidPatternCandidate(c))
        .toList();
  }
}
