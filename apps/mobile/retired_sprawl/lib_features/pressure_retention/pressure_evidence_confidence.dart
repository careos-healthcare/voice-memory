import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';

/// Honest, count-based confidence in a pressure pattern — never overclaims.
enum PressureEvidenceConfidence {
  needsMoreEvidence(label: 'Needs more evidence'),
  earlySignal(label: 'Early signal'),
  repeatingPattern(label: 'Repeating pattern'),
  strongPattern(label: 'Strong pattern');

  const PressureEvidenceConfidence({required this.label});

  final String label;
}

/// Derives evidence confidence from local counts and repetition only.
class PressureEvidenceConfidenceEngine {
  const PressureEvidenceConfidenceEngine();

  PressureEvidenceConfidence fromRecords(List<PressureCheckInRecord> records) {
    final count = records.length;
    if (count < 2) return PressureEvidenceConfidence.needsMoreEvidence;

    final topRepeat = _topOptionRepeat(records);
    if (topRepeat < 2) return PressureEvidenceConfidence.earlySignal;
    if (count >= 5 && topRepeat >= 4) {
      return PressureEvidenceConfidence.strongPattern;
    }
    return PressureEvidenceConfidence.repeatingPattern;
  }

  int _topOptionRepeat(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      counts[record.optionId] = (counts[record.optionId] ?? 0) + 1;
    }
    var top = 0;
    counts.forEach((_, value) {
      if (value > top) top = value;
    });
    return top;
  }
}