import '../features/archive_state_object/archive_state_object.dart';

/// Client-side confidence display (no backend change).
int archiveConfidencePercent({
  required ArchiveHealthV3 health,
  required int evidenceReflectionCount,
}) {
  final base = switch (health) {
    ArchiveHealthV3.strong => 82,
    ArchiveHealthV3.developing => 68,
    ArchiveHealthV3.uncertain => 42,
  };
  final bump = (evidenceReflectionCount.clamp(0, 12) * 2);
  return (base + bump).clamp(35, 95);
}

String archiveConfidencePercentLabel({
  required ArchiveHealthV3 health,
  required int evidenceReflectionCount,
}) {
  return '${archiveConfidencePercent(health: health, evidenceReflectionCount: evidenceReflectionCount)}%';
}
