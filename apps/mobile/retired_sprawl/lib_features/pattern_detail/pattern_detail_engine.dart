import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_copy.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/daily_return_reason_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/positive_pattern_engine.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_engine.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_copy.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds pattern detail from existing grounded engines only.
abstract final class PatternDetailEngine {
  PatternDetailEngine._();

  static const _previewMaxChars = 120;

  static PatternDetailResult? build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return null;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return null;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return null;
    }

    final rawPhrases = _confirmedRepeatPhrases(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
    );
    if (rawPhrases.isEmpty) return null;

    final eligible = ArchiveEvidenceGuard.strongEntries(entries);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      rawPhrases,
      eligible,
    );
    if (grounded.isEmpty) return null;

    final primaryPhrase = grounded.first.trim();
    final patternKey = ArchiveExclusionEngine.normalizePatternKey(
      primaryPhrase,
    );
    final patternLabel = PatternNameEngine.displayLabelForGroundedPhrase(
      primaryPhrase,
    );

    final changed = _whatChanged(
      entries: entries,
      changeProof: changeProof,
      returnChecks: returnChecks,
    );
    final helped = _whatHelped(entries: entries, returnChecks: returnChecks);
    final watchNext = _whatToWatchNext(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );

    return PatternDetailResult(
      patternLabel: patternLabel,
      patternKey: patternKey,
      evidencePhrases: grounded,
      whatChangedBody: changed.body,
      whatChangedSupported: changed.isSupported,
      whatHelpedBody: helped.body,
      whatHelpedSupported: helped.isSupported,
      whatToWatchNextBody: watchNext,
      savedMoments: EntryImportanceEngine.prioritizePatternMoments(
        _savedMoments(
          entries: entries,
          groundedPhrases: grounded,
          patternKey: patternKey,
        ),
      ),
    );
  }

  static bool canShow({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    bool viewingConfirmedRepeatOrTimeline = false,
  }) =>
      build(
        entries: entries,
        confirmedRepeat: confirmedRepeat,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      ) !=
      null;

  static List<String> _confirmedRepeatPhrases({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
  }) {
    if (confirmedRepeat?.showsConfirmedRepeat == true &&
        confirmedRepeat!.evidencePhrases.isNotEmpty) {
      return confirmedRepeat.evidencePhrases;
    }

    final built = EarlyFirstSignalEngine.build(entries: entries);
    if (built?.showsConfirmedRepeat == true &&
        built!.evidencePhrases.isNotEmpty) {
      return built.evidencePhrases;
    }

    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return const [];
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return const [];
    return ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    ).phrases;
  }

  static _SectionBody _whatChanged({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final v2 = WhatChangedV2Engine.weeklyReviewSection(entries: entries);
    if (v2 != null && v2.isSupported) {
      return _SectionBody(body: v2.body.trim(), isSupported: true);
    }

    final changeNotice = EarlyFirstSignalEngine.buildChangeNotice(
      entries: entries,
    );
    if (changeNotice != null && changeNotice.body.trim().isNotEmpty) {
      return _SectionBody(body: changeNotice.body.trim(), isSupported: true);
    }

    if (changeProof != null && changeProof.body.trim().isNotEmpty) {
      final choice = changeProof.latestChoice;
      final line = switch (choice) {
        RepeatReturnCheckChoice.softer =>
          'One later entry sounded softer than before.',
        RepeatReturnCheckChoice.stronger =>
          'One later entry sounded more aware of the pressure.',
        RepeatReturnCheckChoice.same =>
          'Later entries stayed about the same this week.',
        RepeatReturnCheckChoice.changed =>
          'One later entry sounded different from earlier moments.',
      };
      if (choice != RepeatReturnCheckChoice.changed) {
        return _SectionBody(body: line, isSupported: true);
      }
    }

    final choice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    if (choice == RepeatReturnCheckChoice.softer) {
      return const _SectionBody(
        body: 'One later entry sounded more aware of checking capacity.',
        isSupported: true,
      );
    }

    return const _SectionBody(
      body: PatternDetailCopy.notEnoughChangeEvidence,
      isSupported: false,
    );
  }

  static _SectionBody _whatHelped({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final positivePattern = PositivePatternEngine.build(entries: entries);
    final fromMarkers = HelpedTrackingEngine.weeklyReviewSection(
      entries: entries,
      returnChecks: returnChecks,
      positivePattern: positivePattern,
    );
    if (fromMarkers != null && fromMarkers.isSupported) {
      return _SectionBody(body: fromMarkers.body.trim(), isSupported: true);
    }

    return const _SectionBody(
      body: PatternDetailCopy.notEnoughHelpedEvidence,
      isSupported: false,
    );
  }

  static String _whatToWatchNext({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    final dailyReason = DailyReturnReasonEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    final prompt = dailyReason?.prompt.trim();
    if (prompt != null && prompt.isNotEmpty) return prompt;
    return WeeklyArchiveReviewCopy.watchBeforeAgree;
  }

  static List<PatternDetailMoment> _savedMoments({
    required List<JournalEntry> entries,
    required List<String> groundedPhrases,
    required String patternKey,
  }) {
    final normalizedPhrases = groundedPhrases
        .map((phrase) => phrase.toLowerCase().trim())
        .where((phrase) => phrase.isNotEmpty)
        .toList();
    if (normalizedPhrases.isEmpty) return const [];

    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final moments = <PatternDetailMoment>[];
    for (final entry in sorted) {
      if (ArchiveExclusionStore.isExcluded(
        entryId: entry.id,
        patternKey: patternKey,
      )) {
        continue;
      }

      final verdict = ArchiveEvidenceQuality.assess(entry);
      if (!verdict.allowsInsights) continue;

      if (verdict.reason == ArchiveEvidenceQualityReason.genericTestText ||
          ArchiveEvidenceQuality.entryIsGenericTest(entry)) {
        continue;
      }

      if (ComparableEvidenceText.entryHasPendingTranscript(entry)) continue;

      final text = ComparableEvidenceText.userText(entry);
      if (text.isEmpty) continue;

      final normalized = text.toLowerCase();
      final matchesPhrase = normalizedPhrases.any(
        normalized.contains,
      );
      if (!matchesPhrase) continue;

      moments.add(
        PatternDetailMoment(
          entryId: entry.id,
          dateTimeLabel: _dateTimeLabel(entry.createdAt),
          previewText: _truncate(text),
          statusChipLabel: ArchiveHistoryCopy.chipUsedAsEvidence,
          statusKey: 'used_as_evidence',
          isImportant: EntryImportanceStore.isImportant(entry.id),
        ),
      );
    }
    return moments;
  }

  static String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _previewMaxChars) return cleaned;
    return '${cleaned.substring(0, _previewMaxChars - 1).trim()}…';
  }

  static String _dateTimeLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${formatUserFacingDate(createdAt)} · $displayHour:$minute $period';
  }
}

class _SectionBody {
  const _SectionBody({required this.body, required this.isSupported});

  final String body;
  final bool isSupported;
}