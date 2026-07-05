import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../beta/beta_activation_loop_counts.dart';
import '../beta/beta_activation_loop_tracker.dart';
import '../first_proof_action_loop/first_proof_action_loop_model.dart';
import '../first_proof_truth/first_proof_truth_model.dart';
import 'beta_activation_summary_model.dart';
import 'beta_activation_summary_store.dart';

/// Local beta activation summary counters — debug / TestFlight only.
abstract final class BetaActivationSummaryTracker {
  BetaActivationSummaryTracker._();

  static const _sessionDedupeFields = <String>{
    'patternsOpened',
  };

  static final Set<String> _sessionSeen = <String>{};

  @visibleForTesting
  static void resetSessionForTest() {
    _sessionSeen.clear();
  }

  static Future<void> onFunnelEvent(String event) async {
    switch (event) {
      case 'first_proof_moment_seen':
        await _increment('firstProofReached');
      case 'transcript_correction_saved':
        await _increment('transcriptCorrected');
      case 'return_day_flow_answered':
        await _increment('returnDayFlowAnswered');
      case 'beta_feedback_opened':
        await _increment('betaFeedbackOpened');
      case 'beta_feedback_submitted':
        await _increment('betaFeedbackSubmitted');
      default:
        break;
    }
  }

  static Future<void> trackPatternsOpened() =>
      _increment('patternsOpened', sessionDedupe: true);

  static Future<void> trackPatternDetailsOpened() =>
      _increment('patternDetailsOpened');

  static Future<void> trackWeeklyReviewOpened() =>
      _increment('weeklyReviewOpened');

  static Future<void> trackFirstProofTruthAnswer(
    FirstProofTruthAnswer answer,
  ) async {
    final field = switch (answer) {
      FirstProofTruthAnswer.yes => 'firstProofTruthYes',
      FirstProofTruthAnswer.sortOf => 'firstProofTruthSortOf',
      FirstProofTruthAnswer.no => 'firstProofTruthNo',
    };
    await _increment(field);
  }

  static Future<void> trackFirstProofActionSelected(
    FirstProofActionType action,
  ) async {
    final field = switch (action) {
      FirstProofActionType.watchThisNext => 'firstProofActionWatchThisNext',
      FirstProofActionType.viewPatternDetails =>
        'firstProofActionViewPatternDetails',
      FirstProofActionType.renamePattern => 'firstProofActionRenamePattern',
      FirstProofActionType.keepRecording => 'firstProofActionKeepRecording',
      FirstProofActionType.correctTranscript =>
        'firstProofActionCorrectTranscript',
      FirstProofActionType.removeFromPattern =>
        'firstProofActionRemoveFromPattern',
    };
    await _increment(field);
  }

  static Future<BetaActivationSummaryExtension> loadExtension() async {
    if (!AppServices.isInitialized) return BetaActivationSummaryExtension.empty;
    return BetaActivationSummaryStore.fromAppServices().read();
  }

  static Future<
      ({
        BetaActivationLoopCounts loop,
        BetaActivationSummaryExtension extension,
      })> loadAll() async {
    final loop = await BetaActivationLoopTracker.readCounts();
    final extension = await loadExtension();
    return (loop: loop, extension: extension);
  }

  static Future<void> clearExtension() async {
    if (!AppServices.isInitialized) return;
    await BetaActivationSummaryStore.fromAppServices().clear();
  }

  static Future<void> _increment(
    String field, {
    bool sessionDedupe = false,
  }) async {
    if (!AppServices.isInitialized) return;
    if (sessionDedupe && _sessionDedupeFields.contains(field)) {
      if (!_sessionSeen.add(field)) return;
    }
    final counts =
        await BetaActivationSummaryStore.fromAppServices().increment(field);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_ACTIVATION_SUMMARY event=$field '
        'count=${_countFor(counts, field)}',
      );
    }
  }

  static int _countFor(BetaActivationSummaryExtension counts, String field) {
    return switch (field) {
      'firstProofReached' => counts.firstProofReached,
      'patternsOpened' => counts.patternsOpened,
      'patternDetailsOpened' => counts.patternDetailsOpened,
      'weeklyReviewOpened' => counts.weeklyReviewOpened,
      'returnDayFlowAnswered' => counts.returnDayFlowAnswered,
      'transcriptCorrected' => counts.transcriptCorrected,
      'betaFeedbackOpened' => counts.betaFeedbackOpened,
      'betaFeedbackSubmitted' => counts.betaFeedbackSubmitted,
      'firstProofTruthYes' => counts.firstProofTruthYes,
      'firstProofTruthSortOf' => counts.firstProofTruthSortOf,
      'firstProofTruthNo' => counts.firstProofTruthNo,
      'firstProofActionWatchThisNext' => counts.firstProofActionWatchThisNext,
      'firstProofActionViewPatternDetails' =>
        counts.firstProofActionViewPatternDetails,
      'firstProofActionRenamePattern' => counts.firstProofActionRenamePattern,
      'firstProofActionKeepRecording' => counts.firstProofActionKeepRecording,
      'firstProofActionCorrectTranscript' =>
        counts.firstProofActionCorrectTranscript,
      'firstProofActionRemoveFromPattern' =>
        counts.firstProofActionRemoveFromPattern,
      _ => 0,
    };
  }
}
