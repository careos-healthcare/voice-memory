/// How clear a pattern memory is as the archive grows — plain labels only.
enum MemoryQualityLevel {
  earlyRead,
  gettingClearer,
  clearPattern,
  strongPattern,
  changingPattern,
}

extension MemoryQualityLevelIds on MemoryQualityLevel {
  String get id => name;
}

MemoryQualityLevel memoryQualityLevelFromId(String? id) {
  for (final l in MemoryQualityLevel.values) {
    if (l.name == id) return l;
  }
  return MemoryQualityLevel.earlyRead;
}

/// Consumer-facing quality for one pattern memory — no numeric scores.
class MemoryQuality {
  const MemoryQuality({
    required this.level,
    required this.label,
    required this.helperText,
    required this.momentCount,
    required this.checkInCount,
    required this.weekCount,
    required this.hasChangedRecently,
  });

  final MemoryQualityLevel level;
  final String label;
  final String helperText;
  final int momentCount;
  final int checkInCount;
  final int weekCount;
  final bool hasChangedRecently;

  bool get isEarly => level == MemoryQualityLevel.earlyRead;

  bool get isStrong => level == MemoryQualityLevel.strongPattern;

  /// Hide the chip when there is nothing meaningful to say yet.
  bool get shouldShow => momentCount > 0 || checkInCount > 0;

  static const hidden = MemoryQuality(
    level: MemoryQualityLevel.earlyRead,
    label: 'Early read',
    helperText: 'Record a few more moments to make this clearer.',
    momentCount: 0,
    checkInCount: 0,
    weekCount: 0,
    hasChangedRecently: false,
  );
}