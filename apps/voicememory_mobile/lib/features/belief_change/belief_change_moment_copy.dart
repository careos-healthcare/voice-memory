/// Copy for the belief change moment — evidence of softening, not advice.
abstract final class BeliefChangeMomentCopy {
  BeliefChangeMomentCopy._();

  static const title = 'Your archive may be changing';

  static const body =
      'ArchiveMe has seen this pattern before. The latest evidence suggests it may be softening.';

  static const beliefLine = 'Before, your archive believed:';

  static const changeLine = 'Now it has evidence of change:';

  static const evidenceHeading = 'Evidence from your saved moments';

  static const earlierLabel = 'Earlier:';

  static const laterLabel = 'Later:';

  static const footer =
      'This is not advice or a diagnosis. It is a change ArchiveMe noticed in your saved moments.';

  static const viewChangeTimelineCta = 'View change timeline';

  static String formatBeliefExample(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('you ') || lower.startsWith('i ')) {
      return trimmed.endsWith('.') ? trimmed : '$trimmed.';
    }
    return 'You ${trimmed.endsWith('.') ? trimmed : '$trimmed.'}';
  }

  static String formatChangeExample(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('you ') || lower.startsWith('i ')) {
      return trimmed.endsWith('.') ? trimmed : '$trimmed.';
    }
    return 'You ${trimmed.endsWith('.') ? trimmed : '$trimmed.'}';
  }

  static List<String> allVisibleStrings() => [
    title,
    body,
    beliefLine,
    changeLine,
    evidenceHeading,
    earlierLabel,
    laterLabel,
    footer,
    viewChangeTimelineCta,
  ];
}
