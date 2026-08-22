/// Archive Growth Metrics V1 — confidence, evidence, maturity (not streaks).
abstract class ArchiveGrowthMetricsCopy {
  ArchiveGrowthMetricsCopy._();

  static const String confidenceLabel = 'Archive Confidence';
  static const String evidenceLabel = 'Evidence';
  static const String maturityLabel = 'Maturity';

  static String confidenceValue(int percent) => '$percent%';

  static String evidenceValue(int recordingCount) {
    if (recordingCount == 1) return '1 recording';
    return '$recordingCount recordings';
  }
}

abstract class ArchiveJourneyCopy {
  ArchiveJourneyCopy._();

  static const String journeyTitle = 'Archive Journey';
  static const String journeySubtitle =
      'Small rewards as your archive learns from your recordings.';

  static const String day1Title = 'Day 1';
  static const String day1Instruction = 'Record your first thought.';
  static const String day1Pending =
      'Record once to see your first observation.';

  static const String day3Title = 'Day 3';
  static const String day3Instruction =
      'Keep recording — patterns need repetition.';
  static const String day3Pending =
      'A few more recordings will surface your first pattern.';

  static const String day7Title = 'Day 7';
  static const String day7Instruction =
      'A week of evidence lets the archive show change.';
  static const String day7Pending =
      'Return across a week to see your first change.';

  static const String maturityLabel = 'Archive Maturity';
  static const String confidenceLabel = 'Archive Confidence';
  static const String recordingsLabel = 'recordings';
  static const String untilLabel = 'until';
}