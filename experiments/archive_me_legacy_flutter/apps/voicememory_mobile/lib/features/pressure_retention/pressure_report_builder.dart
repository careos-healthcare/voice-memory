import 'pressure_check_in_record.dart';
import 'pressure_evidence_confidence.dart';
import 'pressure_loop_visibility_model.dart';
import 'pressure_weekly_recap_model.dart';

/// Builds a shareable, evidence-only pressure report from local data.
///
/// Reports only what the archive actually holds — counts, labels, and the
/// honest confidence level. No fabricated stats or claims.
class PressureReportBuilder {
  const PressureReportBuilder();

  String toText({
    required List<PressureCheckInRecord> records,
    required PressureLoopVisibility visibility,
    required PressureWeeklyRecap recap,
    required PressureEvidenceConfidence confidence,
  }) {
    final buffer = StringBuffer()
      ..writeln('ArchiveMe — Pressure report')
      ..writeln()
      ..writeln('Confidence: ${confidence.label}')
      ..writeln(
        'Pressure moments noticed this week: ${visibility.noticedThisWeek}',
      )
      ..writeln(
        'Times you chose to stop this week: ${visibility.choseToStopCount}',
      );

    final strongest = visibility.strongestPhrase;
    if (strongest != null) {
      buffer.writeln('Showed up most as: "$strongest"');
    }
    if (recap.mostCommonContextLabel != null) {
      buffer.writeln('Most common context: ${recap.mostCommonContextLabel}');
    }
    if (visibility.streakDays > 0) {
      buffer.writeln(
        'Noticed-the-loop streak: ${visibility.streakDays} '
        'day${visibility.streakDays == 1 ? '' : 's'}',
      );
    }

    buffer
      ..writeln()
      ..writeln(
        'Based on ${records.length} saved '
        'moment${records.length == 1 ? '' : 's'} on this device.',
      );

    return buffer.toString().trimRight();
  }
}
