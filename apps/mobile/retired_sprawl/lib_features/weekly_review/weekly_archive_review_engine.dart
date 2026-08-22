import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/daily_return_reason_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/early_archive/positive_pattern_engine.dart';
import 'package:archiveme_mobile/features/early_archive/positive_pattern_models.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_engine.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the weekly archive review from existing evidence engines only.
abstract final class WeeklyArchiveReviewEngine {
  WeeklyArchiveReviewEngine._();

  static const weekWindowDays = 7;
  static const minEntriesForFullReview = 5;
  static const minDistinctDaysForTrigger = 3;

  static WeeklyArchiveReviewResult? build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!shouldShow(entries: entries, returnChecks: returnChecks)) {
      return null;
    }

    final reviewEntries = _reviewEntries(entries);
    final repeatSource =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: reviewEntries);
    final positivePattern = PositivePatternEngine.build(entries: entries);

    final repeated = _repeatedSection(
      confirmedRepeat: repeatSource,
      entries: reviewEntries,
    );
    final changed = _changedSection(
      entries: reviewEntries,
      changeProof: changeProof,
      returnChecks: returnChecks,
    );
    final helped = _helpedSection(
      entries: entries,
      returnChecks: returnChecks,
      positivePattern: positivePattern,
    );
    final dailyReason = DailyReturnReasonEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    final nextToWatch =
        dailyReason?.prompt ?? WeeklyArchiveReviewCopy.watchBeforeAgree;

    final usableCount = ArchiveEvidenceQualityGate.usableCount(entries);
    final fullByVolume = usableCount >= minEntriesForFullReview;
    final fullByProofPath = _firstProofPlusLaterReturn(
      entries: entries,
      returnChecks: returnChecks,
    );
    final hasGroundedContent =
        repeated.isSupported || changed.isSupported || helped.isSupported;

    if (!fullByVolume && !fullByProofPath && !hasGroundedContent) {
      return const WeeklyArchiveReviewResult(
        state: WeeklyArchiveReviewState.forming,
        title: WeeklyArchiveReviewCopy.formingTitle,
        formingBody: WeeklyArchiveReviewCopy.formingBody,
      );
    }

    return WeeklyArchiveReviewResult(
      state: WeeklyArchiveReviewState.full,
      title: WeeklyArchiveReviewCopy.title,
      subtitle: WeeklyArchiveReviewCopy.subtitle,
      whatRepeated: repeated,
      whatChanged: changed,
      whatHelped: helped,
      whatToWatchNext: WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatToWatchLabel,
        body: nextToWatch,
        isSupported: true,
      ),
    );
  }

  static bool shouldShow({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    if (entries.isEmpty) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (_onlyQuietDayEntries(entries)) return false;
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;

    final usable = ArchiveEvidenceQualityGate.usableEntries(entries);
    if (usable.length >= minEntriesForFullReview) return true;
    if (_distinctCalendarDays(usable) >= minDistinctDaysForTrigger) return true;
    if (_firstProofPlusLaterReturn(
      entries: entries,
      returnChecks: returnChecks,
    )) {
      return true;
    }
    return false;
  }

  static bool shouldShowOnSurface({
    required bool loaded,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      shouldShow(entries: entries, returnChecks: returnChecks);

  static List<JournalEntry> _reviewEntries(List<JournalEntry> entries) {
    final eligible = ArchiveExclusionEngine.eligibleForActivePattern(entries);
    if (eligible.isEmpty) return const [];

    final anchor = eligible.last.createdAt;
    final weekStart = anchor.subtract(const Duration(days: weekWindowDays));
    final weekEntries = eligible
        .where((entry) => !entry.createdAt.isBefore(weekStart))
        .toList();
    if (weekEntries.length >= 2) return weekEntries;

    if (eligible.length >= 3) {
      return eligible.sublist(eligible.length - 3);
    }
    return eligible;
  }

  static int _distinctCalendarDays(Iterable<JournalEntry> entries) {
    return entries
        .map((entry) {
          final date = entry.createdAt;
          return DateTime(date.year, date.month, date.day);
        })
        .toSet()
        .length;
  }

  static bool _onlyQuietDayEntries(List<JournalEntry> entries) {
    final withText = entries
        .map(ComparableEvidenceText.userText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) return false;
    return withText.every(RecordCaptureModeEngine.isQuietDayText);
  }

  static bool _firstProofPlusLaterReturn({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final eligible = ArchiveExclusionEngine.eligibleForActivePattern(entries);
    if (eligible.length < 4) return false;

    final hadFirstProof =
        FirstProofMomentEngine.build(entries: eligible) != null ||
        (eligible.length >= 3 &&
            EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(
              eligible.sublist(0, 3),
            ));
    if (!hadFirstProof) return false;

    if (RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks)) {
      return true;
    }
    return EarlyFirstSignalEngine.buildChangeNotice(entries: eligible) != null;
  }

  static WeeklyArchiveReviewSection _repeatedSection({
    required List<JournalEntry> entries, EarlyFirstSignalModel? confirmedRepeat,
  }) {
    var phrases = const <String>[];
    if (confirmedRepeat?.showsConfirmedRepeat == true) {
      phrases = confirmedRepeat!.evidencePhrases.isNotEmpty
          ? confirmedRepeat.evidencePhrases
          : ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases;
    } else {
      phrases = ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases;
    }

    final grounded = phrases.where((phrase) {
      final trimmed = phrase.replaceAll('"', '').trim();
      return trimmed.isNotEmpty &&
          !ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels.contains(
            trimmed.toLowerCase(),
          );
    }).toList();

    if (grounded.isEmpty) {
      return const WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatRepeatedLabel,
        body: WeeklyArchiveReviewCopy.notEnoughEvidenceYet,
        isSupported: false,
      );
    }

    final phrase = grounded.first.replaceAll('"', '').trim();
    final displayPhrase = PatternNameEngine.displayLabelForGroundedPhrase(
      phrase,
    );
    return WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatRepeatedLabel,
      body: "'$displayPhrase' appeared across several moments.",
      isSupported: true,
      evidencePhrases: grounded,
    );
  }

  static WeeklyArchiveReviewSection _changedSection({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final v2Marker = WhatChangedV2Engine.weeklyReviewSection(entries: entries);
    if (v2Marker != null) return v2Marker;

    final changeNotice = EarlyFirstSignalEngine.buildChangeNotice(
      entries: entries,
    );
    if (changeNotice != null && changeNotice.body.trim().isNotEmpty) {
      return WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatChangedLabel,
        body: changeNotice.body.trim(),
        isSupported: true,
      );
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
      return WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatChangedLabel,
        body: line,
        isSupported: choice != RepeatReturnCheckChoice.changed,
      );
    }

    final choice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    if (choice == RepeatReturnCheckChoice.softer) {
      return const WeeklyArchiveReviewSection(
        label: WeeklyArchiveReviewCopy.whatChangedLabel,
        body: 'One later entry sounded more aware of checking capacity.',
        isSupported: true,
      );
    }

    return const WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatChangedLabel,
      body: WeeklyArchiveReviewCopy.notEnoughEvidenceYet,
      isSupported: false,
    );
  }

  static WeeklyArchiveReviewSection _helpedSection({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    PositivePatternResult? positivePattern,
  }) {
    final fromMarkers = HelpedTrackingEngine.weeklyReviewSection(
      entries: entries,
      returnChecks: returnChecks,
      positivePattern: positivePattern,
    );
    if (fromMarkers != null) return fromMarkers;

    return const WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatHelpedLabel,
      body: WeeklyArchiveReviewCopy.notEnoughEvidenceYet,
      isSupported: false,
    );
  }
}