import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_insight_quality_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_insight_summary.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds a cautious loop map from confirmed-repeat evidence only.
abstract final class ConfirmedRepeatThoughtMapEngine {
  ConfirmedRepeatThoughtMapEngine._();

  static ThoughtMapResult? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }

    final insight = EarlyArchiveInsightQualityEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(entries);
    final phrases = evidence.phrases;

    final trigger = ThoughtMapSection(
      id: ThoughtMapSectionId.trigger,
      label: ConfirmedRepeatThoughtMapCopy.triggerLabel,
      question: ConfirmedRepeatThoughtMapCopy.triggerQuestion,
      unknownPrompt: ConfirmedRepeatThoughtMapCopy.triggerUnknown,
      value: insight.triggerSummary,
    );
    final thought = ThoughtMapSection(
      id: ThoughtMapSectionId.thought,
      label: ConfirmedRepeatThoughtMapCopy.thoughtLabel,
      question: ConfirmedRepeatThoughtMapCopy.thoughtQuestion,
      unknownPrompt: ConfirmedRepeatThoughtMapCopy.thoughtUnknown,
      value: _thoughtValue(phrases),
    );
    final action = ThoughtMapSection(
      id: ThoughtMapSectionId.action,
      label: ConfirmedRepeatThoughtMapCopy.actionLabel,
      question: ConfirmedRepeatThoughtMapCopy.actionQuestion,
      unknownPrompt: ConfirmedRepeatThoughtMapCopy.actionUnknown,
      value: _actionValue(phrases, insight.repeatSummary),
    );
    final result = ThoughtMapSection(
      id: ThoughtMapSectionId.result,
      label: ConfirmedRepeatThoughtMapCopy.resultLabel,
      question: ConfirmedRepeatThoughtMapCopy.resultQuestion,
      unknownPrompt: ConfirmedRepeatThoughtMapCopy.resultUnknown,
      value: _resultValue(insight: insight, returnChecks: returnChecks),
    );

    final sections = [trigger, thought, action, result];
    return ThoughtMapResult(
      title: ConfirmedRepeatThoughtMapCopy.title,
      sections: sections,
      firstMissingSection: _firstMissing(sections),
    );
  }

  static String? _thoughtValue(List<String> phrases) {
    if (phrases.isEmpty) return null;
    if (phrases.length == 1) {
      return '"${phrases.first}"';
    }
    return phrases.map((phrase) => '"$phrase"').join(', ');
  }

  static String? _actionValue(List<String> phrases, String? repeatSummary) {
    if (phrases.length >= 2) {
      return '"${phrases[1]}"';
    }
    final cleaned = _repeatAsAction(repeatSummary);
    if (cleaned != null) return cleaned;
    return null;
  }

  static String? _repeatAsAction(String? repeatSummary) {
    if (repeatSummary == null || repeatSummary.trim().isEmpty) return null;
    const prefix = 'This keeps coming back around ';
    if (repeatSummary.startsWith(prefix)) {
      final body = repeatSummary.substring(prefix.length).trim();
      if (body.endsWith('.')) {
        return body.substring(0, body.length - 1).trim();
      }
      return body.isEmpty ? null : body;
    }
    return null;
  }

  static String? _resultValue({
    required EarlyArchiveInsightSummary insight,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    final trend = RepeatReturnCheckTrendEngine.changeProofBody(returnChecks);
    if (trend != null && trend.trim().isNotEmpty) return trend;
    if (insight.softeningSummary != null &&
        insight.softeningSummary!.trim().isNotEmpty) {
      return insight.softeningSummary;
    }
    if (insight.helpfulActionSummary != null &&
        insight.helpfulActionSummary!.trim().isNotEmpty) {
      return insight.helpfulActionSummary;
    }
    return null;
  }

  static ThoughtMapSectionId? _firstMissing(List<ThoughtMapSection> sections) {
    for (final section in sections) {
      if (!section.isKnown) return section.id;
    }
    return null;
  }
}