import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../timeline/timeline_entry_display.dart';
import 'positive_pattern_models.dart';
import 'positive_reinforcement_copy.dart';

/// Built positive reinforcement loop from an existing Positive Pattern.
class PositiveReinforcementResult {
  const PositiveReinforcementResult({
    required this.title,
    required this.body,
    required this.evidencePhrases,
    required this.guidedRecordPrompt,
    required this.isCompletion,
    required this.primaryCue,
  });

  final String title;
  final String body;
  final List<String> evidencePhrases;
  final String guidedRecordPrompt;
  final bool isCompletion;
  final String primaryCue;

  bool get hasEvidence => evidencePhrases.isNotEmpty;
}

abstract final class PositiveReinforcementEngine {
  PositiveReinforcementEngine._();

  static const minEntriesForCompletion = 3;

  static PositiveReinforcementResult? build({
    required PositivePatternResult? positivePattern,
    required List<JournalEntry> entries,
    bool helpfulActionCapturedMilestone = false,
  }) {
    if (positivePattern == null || !positivePattern.hasEvidence) return null;

    final primaryCue = _primaryCue(positivePattern);
    if (primaryCue.isEmpty) return null;

    final cueEntryCount = _entriesWithCue(entries, primaryCue);
    final appearedAgain =
        helpfulActionCapturedMilestone ||
        cueEntryCount >= minEntriesForCompletion;

    if (appearedAgain) {
      return PositiveReinforcementResult(
        title: PositiveReinforcementCopy.completionTitle,
        body: PositiveReinforcementCopy.completionBody,
        evidencePhrases: positivePattern.evidencePhrases,
        guidedRecordPrompt: PositiveReinforcementCopy.guidedRecordPrompt,
        isCompletion: true,
        primaryCue: primaryCue,
      );
    }

    return PositiveReinforcementResult(
      title: PositiveReinforcementCopy.title,
      body: PositiveReinforcementCopy.body,
      evidencePhrases: positivePattern.evidencePhrases,
      guidedRecordPrompt: PositiveReinforcementCopy.guidedRecordPrompt,
      isCompletion: false,
      primaryCue: primaryCue,
    );
  }

  static String _primaryCue(PositivePatternResult pattern) {
    if (pattern.evidencePhrases.isEmpty) return '';
    return pattern.evidencePhrases.first
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
  }

  static int _entriesWithCue(List<JournalEntry> entries, String cueLower) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    var count = 0;
    for (final entry in eligible) {
      final text = _entryText(entry).toLowerCase();
      if (text.contains(cueLower)) count++;
    }
    return count;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }
}
