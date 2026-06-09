/// Which Pro value moment the preview explains.
enum ProValuePreviewType {
  memoryLimit,
  patternMap,
  archiveTimeline,
  archiveMemory,
  keyMomentSearch,
  monthlyReview,
  privateExport,
}

/// Consumer-visible preview of what Pro unlocks before the paywall.
class ProValuePreview {
  const ProValuePreview({
    required this.type,
    required this.title,
    required this.body,
    required this.previewBullets,
    required this.ctaLabel,
    this.trigger,
  });

  final ProValuePreviewType type;
  final String title;
  final String body;
  final List<String> previewBullets;
  final String ctaLabel;

  /// Optional paywall trigger id (e.g. `patternMapFull`).
  final String? trigger;

  String get typeId => type.name;
}
