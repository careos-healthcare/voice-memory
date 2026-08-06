import 'confirmed_repeat_thought_map_models.dart';

/// One row in the loop-forming section — known value or honest prompt.
class ArchiveSummaryLoopRow {
  const ArchiveSummaryLoopRow({
    required this.label,
    required this.displayText,
    required this.isKnown,
    required this.sectionId,
  });

  final String label;
  final String displayText;
  final bool isKnown;
  final ThoughtMapSectionId sectionId;
}

/// Keeps-repeating section from confirmed-repeat proof.
class ArchiveSummaryRepeatingSection {
  const ArchiveSummaryRepeatingSection({
    required this.bodyLines,
    this.evidencePhrases = const [],
    this.isFallback = false,
  });

  final List<String> bodyLines;
  final List<String> evidencePhrases;
  final bool isFallback;
}

/// Next-best record prompt chosen from missing loop/change/help data.
class ArchiveSummaryRecordNext {
  const ArchiveSummaryRecordNext({
    required this.prompt,
    required this.guidedRecordPrompt,
    this.targetSection,
  });

  final String prompt;
  final String guidedRecordPrompt;
  final ThoughtMapSectionId? targetSection;

  bool get needsTriggerCapture => targetSection == ThoughtMapSectionId.trigger;
  bool get needsResultCapture => targetSection == ThoughtMapSectionId.result;
}

/// Unified archive overview composed from existing proof engines.
class ArchiveSummaryResult {
  const ArchiveSummaryResult({
    required this.title,
    required this.keepsRepeating,
    required this.loopRows,
    required this.changingLine,
    required this.changingIsFallback,
    required this.whatHelpsLine,
    required this.whatHelpsIsFallback,
    required this.recordNext,
  });

  final String title;
  final ArchiveSummaryRepeatingSection keepsRepeating;
  final List<ArchiveSummaryLoopRow> loopRows;
  final String changingLine;
  final bool changingIsFallback;
  final String whatHelpsLine;
  final bool whatHelpsIsFallback;
  final ArchiveSummaryRecordNext recordNext;

  bool get hasLoopForming => loopRows.isNotEmpty;
}
