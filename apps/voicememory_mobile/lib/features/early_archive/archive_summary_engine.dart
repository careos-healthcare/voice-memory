import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'archive_summary_copy.dart';
import 'archive_summary_model.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'confirmed_repeat_thought_map_engine.dart';
import 'confirmed_repeat_thought_map_models.dart';
import 'early_evidence_timeline_engine.dart';
import 'early_first_signal_engine.dart';
import 'positive_pattern_copy.dart';
import 'positive_pattern_engine.dart';
import 'positive_pattern_models.dart';

/// Composes the Archive Summary from existing proof engines only.
abstract final class ArchiveSummaryEngine {
  ArchiveSummaryEngine._();

  static ArchiveSummaryResult? build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;

    final thoughtMap = ConfirmedRepeatThoughtMapEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
    );
    final positivePattern = PositivePatternEngine.build(entries: entries);

    final keepsRepeating = _keepsRepeating(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      timeline: timeline,
    );
    final loopRows = _loopRows(thoughtMap);
    final changing = _changingLine(changeProof);
    final whatHelps = _whatHelpsLine(positivePattern);
    final recordNext = _recordNext(
      thoughtMap: thoughtMap,
      changeProof: changeProof,
      positivePattern: positivePattern,
    );

    return ArchiveSummaryResult(
      title: ArchiveSummaryCopy.title,
      keepsRepeating: keepsRepeating,
      loopRows: loopRows,
      changingLine: changing.line,
      changingIsFallback: changing.isFallback,
      whatHelpsLine: whatHelps.line,
      whatHelpsIsFallback: whatHelps.isFallback,
      recordNext: recordNext,
    );
  }

  static ArchiveSummaryRepeatingSection _keepsRepeating({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
  }) {
    if (confirmedRepeat?.showsConfirmedRepeat == true) {
      final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
      final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
        confirmedRepeat!.evidencePhrases,
        eligible,
      );
      final primaryPhrase = grounded.isNotEmpty ? grounded.first : null;
      final bodyLines = <String>[
        if (primaryPhrase != null)
          ArchiveSummaryCopy.keepsRepeatingWithPhrase(primaryPhrase)
        else
          ArchiveSummaryCopy.keepsRepeatingForming,
        ...confirmedRepeat.lines,
      ];

      return ArchiveSummaryRepeatingSection(
        bodyLines: bodyLines,
        evidencePhrases: grounded,
        isFallback: primaryPhrase == null,
      );
    }

    if (timeline != null) {
      final repeatItem = timeline.items
          .where(
            (item) => item.kind == EarlyEvidenceTimelineItemKind.repeatConfirmed,
          )
          .firstOrNull;
      if (repeatItem != null) {
        return ArchiveSummaryRepeatingSection(
          bodyLines: [repeatItem.title, repeatItem.body],
          evidencePhrases: timeline.evidencePhrases,
        );
      }
    }

    return const ArchiveSummaryRepeatingSection(
      bodyLines: [ArchiveSummaryCopy.keepsRepeatingFallback],
      isFallback: true,
    );
  }

  static List<ArchiveSummaryLoopRow> _loopRows(ThoughtMapResult? thoughtMap) {
    if (thoughtMap == null) return const [];

    return thoughtMap.sections
        .map(
          (section) => ArchiveSummaryLoopRow(
            label: section.label,
            displayText: section.displayText,
            isKnown: section.isKnown,
            sectionId: section.id,
          ),
        )
        .toList();
  }

  static ({String line, bool isFallback}) _changingLine(
    RepeatReturnCheckChangeProof? changeProof,
  ) {
    if (changeProof != null && changeProof.body.trim().isNotEmpty) {
      return (line: changeProof.body.trim(), isFallback: false);
    }
    return (
      line: ArchiveSummaryCopy.changingFallback,
      isFallback: true,
    );
  }

  static ({String line, bool isFallback}) _whatHelpsLine(
    PositivePatternResult? positivePattern,
  ) {
    if (positivePattern != null && positivePattern.evidencePhrases.isNotEmpty) {
      final phrase = positivePattern.evidencePhrases.first
          .replaceAll('"', '')
          .trim();
      return (
        line: ArchiveSummaryCopy.whatHelpsWithPhrase(phrase),
        isFallback: false,
      );
    }
    return (
      line: ArchiveSummaryCopy.whatHelpsFallback,
      isFallback: true,
    );
  }

  static ArchiveSummaryRecordNext _recordNext({
    ThoughtMapResult? thoughtMap,
    RepeatReturnCheckChangeProof? changeProof,
    PositivePatternResult? positivePattern,
  }) {
    if (thoughtMap != null) {
      for (final section in thoughtMap.sections) {
        if (section.isKnown) continue;
        return ArchiveSummaryRecordNext(
          prompt: _promptForSection(section.id),
          guidedRecordPrompt: section.guidedRecordPrompt,
          targetSection: section.id,
        );
      }
    }

    if (changeProof == null) {
      return const ArchiveSummaryRecordNext(
        prompt: ArchiveSummaryCopy.recordNextChangeUnknown,
        guidedRecordPrompt: ArchiveSummaryCopy.recordNextChangeGuided,
      );
    }

    if (positivePattern == null || !positivePattern.hasEvidence) {
      return ArchiveSummaryRecordNext(
        prompt: ArchiveSummaryCopy.recordNextPositiveMissing,
        guidedRecordPrompt: PositivePatternCopy.guidedRecordPrompt,
      );
    }

    return const ArchiveSummaryRecordNext(
      prompt: ArchiveSummaryCopy.recordNextChangeUnknown,
      guidedRecordPrompt: ArchiveSummaryCopy.recordNextChangeGuided,
    );
  }

  static String _promptForSection(ThoughtMapSectionId id) =>
      switch (id) {
        ThoughtMapSectionId.trigger =>
          ArchiveSummaryCopy.recordNextTriggerUnknown,
        ThoughtMapSectionId.thought =>
          ArchiveSummaryCopy.recordNextThoughtUnknown,
        ThoughtMapSectionId.action =>
          ArchiveSummaryCopy.recordNextActionUnknown,
        ThoughtMapSectionId.result =>
          ArchiveSummaryCopy.recordNextResultUnknown,
      };
}
