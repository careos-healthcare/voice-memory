import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../current_relevance/current_relevance_model.dart';
import '../current_relevance/current_relevance_store.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../present_day_relevance/present_day_relevance_model.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'correction_memory_analytics.dart';
import 'correction_memory_copy.dart';
import 'correction_memory_model.dart';
import 'correction_memory_store.dart';

/// Builds and applies archive corrections from existing relevance answers.
abstract final class CorrectionMemoryEngine {
  CorrectionMemoryEngine._();

  static const recentWindowDays = 7;

  static CorrectionMemoryResult? build({
    required List<JournalEntry> entries,
    required String source,
    DateTime? now,
  }) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) return null;

    final record = CorrectionMemoryStore.recordFor(proofKey);
    if (record == null) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final returnedAfterFaded = _returnedAfterFaded(
      record: record,
      entries: entries,
      hasConfirmedRepeat: hasConfirmedRepeat,
      now: now ?? DateTime.now(),
    );

    return CorrectionMemoryResult(
      shouldShow: true,
      proofKey: proofKey,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      state: record.state,
      returnedAfterFaded: returnedAfterFaded,
      title: CorrectionMemoryCopy.title,
      body: returnedAfterFaded && record.state == CorrectionMemoryState.faded
          ? CorrectionMemoryCopy.returnedAfterFadedBody
          : CorrectionMemoryCopy.bodyFor(record.state),
      footer: CorrectionMemoryCopy.footer,
      differentiationLine: CorrectionMemoryCopy.differentiationLine,
    );
  }

  static CorrectionMemorySnapshot? snapshotFor({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final built = build(entries: entries, source: 'snapshot', now: now);
    return built?.snapshot;
  }

  static Future<void> saveFromAnswer({
    required String proofKey,
    required CurrentRelevanceAnswer answer,
    required int entryCountAtCapture,
    required bool hasConfirmedRepeat,
    required String source,
  }) async {
    await CorrectionMemoryStore.instance().saveFromAnswer(
      proofKey: proofKey,
      answer: answer,
      entryCountAtCapture: entryCountAtCapture,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    final result = CorrectionMemoryResult(
      shouldShow: true,
      proofKey: proofKey,
      entryCount: entryCountAtCapture,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      state: answer.toCorrectionMemoryState(),
      returnedAfterFaded: false,
      title: CorrectionMemoryCopy.title,
      body: CorrectionMemoryCopy.bodyFor(answer.toCorrectionMemoryState()),
      footer: CorrectionMemoryCopy.footer,
      differentiationLine: CorrectionMemoryCopy.differentiationLine,
    );
    CorrectionMemoryAnalytics.saved(source: source, result: result);
  }

  static PresentDayRelevanceState presentDayStateFor({
    required CorrectionMemorySnapshot? correction,
    required PresentDayRelevanceState fallback,
  }) {
    if (correction == null) return fallback;
    if (correction.returnedAfterFaded) return PresentDayRelevanceState.current;
    return switch (correction.state) {
      CorrectionMemoryState.stillCurrent => PresentDayRelevanceState.current,
      CorrectionMemoryState.partlyCurrent => PresentDayRelevanceState.softened,
      CorrectionMemoryState.faded => PresentDayRelevanceState.fading,
      CorrectionMemoryState.unsure => PresentDayRelevanceState.unclear,
    };
  }

  static String presentDayStateBodyFor({
    required CorrectionMemorySnapshot? correction,
    required PresentDayRelevanceState state,
    required String fallback,
  }) {
    if (correction == null) return fallback;
    if (correction.returnedAfterFaded) {
      return CorrectionMemoryCopy.returnedAfterFadedBody;
    }
    return switch (correction.state) {
      CorrectionMemoryState.stillCurrent =>
        'You marked this as still affecting you. ArchiveMe will treat fresh returns as stronger evidence.',
      CorrectionMemoryState.partlyCurrent =>
        'You marked this as only partly current. ArchiveMe will keep it in view, but not treat it as the whole story.',
      CorrectionMemoryState.faded =>
        'You marked this as not really current. ArchiveMe will treat it as background unless it returns.',
      CorrectionMemoryState.unsure =>
        'You were not sure. ArchiveMe will keep this lightly in view and wait for stronger evidence.',
    };
  }

  static String evidenceExplanationFor({
    required CorrectionMemorySnapshot? correction,
    required String fallback,
    required bool isRepeatedState,
  }) {
    if (correction == null) return fallback;
    if (correction.returnedAfterFaded && isRepeatedState) {
      return CorrectionMemoryCopy.returnedAfterFadedEvidenceLine;
    }
    return switch (correction.state) {
      CorrectionMemoryState.stillCurrent when isRepeatedState =>
        'You marked this as still affecting you. Fresh returns count as stronger evidence.',
      CorrectionMemoryState.partlyCurrent =>
        '$fallback ArchiveMe will keep this in view, but not as the whole story.',
      CorrectionMemoryState.faded =>
        '$fallback ArchiveMe will treat this as background unless it returns.',
      CorrectionMemoryState.unsure =>
        '$fallback ArchiveMe will keep this lightly in view until stronger evidence appears.',
      _ => fallback,
    };
  }

  static bool shouldShow({
    required CorrectionMemoryResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldShowOnRecordReady({
    required CorrectionMemoryResult? result,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnPatterns({
    required CorrectionMemoryResult? result,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static bool _returnedAfterFaded({
    required CorrectionMemoryRecord record,
    required List<JournalEntry> entries,
    required bool hasConfirmedRepeat,
    required DateTime now,
  }) {
    if (record.state != CorrectionMemoryState.faded) return false;
    if (!hasConfirmedRepeat) return false;
    if (entries.length <= record.entryCountAtCapture) return false;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return false;
    final latest = eligible.last.createdAt;
    return now.difference(latest).inDays <= recentWindowDays;
  }
}
