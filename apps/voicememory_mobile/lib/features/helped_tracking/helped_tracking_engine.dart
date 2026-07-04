import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/positive_pattern_engine.dart';
import '../early_archive/positive_pattern_models.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../weekly_review/weekly_archive_review_copy.dart';
import '../weekly_review/weekly_archive_review_model.dart';
import '../what_changed/what_changed_v2_model.dart';
import '../what_changed/what_changed_v2_store.dart';
import 'helped_tracking_copy.dart';
import 'helped_tracking_model.dart';
import 'helped_tracking_store.dart';

/// User-reported helped evidence — display only, no inference.
abstract final class HelpedTrackingEngine {
  HelpedTrackingEngine._();

  static const minMarkersForStrongerClaim = 2;

  static const promptOptions = [
    HelpedTrackingOption.paused,
    HelpedTrackingOption.saidNo,
    HelpedTrackingOption.askedForTime,
    HelpedTrackingOption.talkedToSomeone,
    HelpedTrackingOption.nothingHelped,
    HelpedTrackingOption.somethingElse,
  ];

  static HelpedTrackingPrompt? buildPrompt({
    required List<JournalEntry> entries,
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    required bool showWhatChangedV2,
  }) {
    if (!isPostSaveDone || isDegradedPostSave) return null;
    if (showWhatChangedV2) return null;
    if (!_allowsPrompt(entries)) return null;

    final latestEntryId = RepeatReturnCheckStore.latestSavedEntryId(entries);
    final changeMarker = WhatChangedV2Store.cached
        .where((record) => record.entryId == latestEntryId)
        .firstOrNull;
    if (changeMarker != null &&
        changeMarker.option != WhatChangedV2Option.somethingHelped) {
      return null;
    }

    if (HelpedTrackingStore.cached
        .any((record) => record.entryId == latestEntryId)) {
      return null;
    }

    return HelpedTrackingPrompt(
      entryId: latestEntryId,
      entryCount: entries.length,
      options: promptOptions,
    );
  }

  static bool hasHelpfulMarkers(Iterable<HelpedTrackingRecord> records) =>
      records.any((record) => record.option.countsAsHelped);

  static WeeklyArchiveReviewSection? weeklyReviewSection({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    PositivePatternResult? positivePattern,
  }) {
    final markers = _markersForEntries(entries);
    if (!hasHelpfulMarkers(markers)) {
      return positivePattern != null &&
              positivePattern.evidencePhrases.isNotEmpty
          ? WeeklyArchiveReviewSection(
              label: WeeklyArchiveReviewCopy.whatHelpedLabel,
              body: positivePattern.evidencePhrases.first
                  .replaceAll('"', '')
                  .trim(),
              isSupported: true,
              evidencePhrases: positivePattern.evidencePhrases,
            )
          : null;
    }

    final latestHelpful = markers
        .where((record) => record.option.countsAsHelped)
        .first;
    final sameOptionCount = markers
        .where((record) => record.option == latestHelpful.option)
        .length;
    final softerSignal = RepeatReturnCheckTrendEngine.latestChoice(
          returnChecks,
        ) ==
        RepeatReturnCheckChoice.softer;

    final body = latestHelpful.option == HelpedTrackingOption.somethingElse &&
            latestHelpful.hasFreeText
        ? latestHelpful.freeText!.trim()
        : sameOptionCount >= minMarkersForStrongerClaim && softerSignal
            ? HelpedTrackingCopy.strongerWithSofter(
                latestHelpful.option.summaryVerb,
              )
            : HelpedTrackingCopy.singleReported(
                latestHelpful.option.summaryVerb,
              );

    return WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatHelpedLabel,
      body: body,
      isSupported: true,
    );
  }

  static String? archiveHistoryNoteForEntry(String entryId) {
    final record = HelpedTrackingStore.cached
        .where((marker) => marker.entryId == entryId)
        .firstOrNull;
    if (record == null) return null;
    if (record.option == HelpedTrackingOption.somethingElse &&
        record.hasFreeText) {
      return HelpedTrackingCopy.archiveHistoryNote(record.freeText!.trim());
    }
    return HelpedTrackingCopy.archiveHistoryNote(record.option.label);
  }

  static bool _allowsPrompt(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return false;
    }
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;

    final latest = ArchiveEvidenceGuard.eligibleEntries(entries).lastOrNull ??
        entries.last;
    final text = ComparableEvidenceText.userText(latest);
    if (text.trim().isEmpty) return false;
    if (RecordCaptureModeEngine.isQuietDayText(text)) return false;

    return true;
  }

  static List<HelpedTrackingRecord> _markersForEntries(
    List<JournalEntry> entries,
  ) {
    final ids = entries.map((entry) => entry.id).toSet();
    return HelpedTrackingStore.cached
        .where((record) => ids.contains(record.entryId))
        .toList();
  }
}
