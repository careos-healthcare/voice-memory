import '../beta/beta_activation_loop_counts.dart';
import 'beta_activation_summary_copy.dart';
import 'beta_activation_summary_model.dart';

/// Builds beta activation summary from local loop + extension counters.
abstract final class BetaActivationSummaryEngine {
  BetaActivationSummaryEngine._();

  static BetaActivationSummary build({
    required BetaActivationLoopCounts loop,
    required BetaActivationSummaryExtension extension,
  }) {
    return BetaActivationSummary(
      appOpens: loop.appOpened,
      recordScreenViews: loop.recordScreenSeen,
      firstMomentSaved: loop.firstMomentSaved,
      secondMomentSaved: loop.secondMomentSaved,
      firstProofReached: extension.firstProofReached,
      patternsOpened: extension.patternsOpened,
      patternDetailsOpened: extension.patternDetailsOpened,
      weeklyReviewOpened: extension.weeklyReviewOpened,
      returnDayFlowAnswered: extension.returnDayFlowAnswered,
      transcriptCorrected: extension.transcriptCorrected,
      betaFeedbackOpened: extension.betaFeedbackOpened,
      betaFeedbackSubmitted: extension.betaFeedbackSubmitted,
      proScreenOpened: loop.paywallSeen,
      restorePurchasesTapped: loop.restoreTapped,
      returnedAfterFirstProof: loop.returnedAfterFirstProof,
      status: resolveStatus(loop: loop, extension: extension),
    );
  }

  static BetaActivationStatus resolveStatus({
    required BetaActivationLoopCounts loop,
    required BetaActivationSummaryExtension extension,
  }) {
    if (extension.weeklyReviewOpened > 0) {
      return BetaActivationStatus.weeklyReviewReached;
    }
    if (loop.returnedAfterFirstProof > 0 ||
        extension.returnDayFlowAnswered > 0) {
      return BetaActivationStatus.returnedAfterProof;
    }
    if (extension.firstProofReached > 0) {
      return BetaActivationStatus.firstProofReached;
    }
    if (loop.secondMomentSaved > 0) {
      return BetaActivationStatus.almostAtFirstProof;
    }
    if (loop.firstMomentSaved > 0) {
      return BetaActivationStatus.firstMomentSaved;
    }
    return BetaActivationStatus.notStarted;
  }

  static String buildCopyText(BetaActivationSummary summary) {
    final buffer = StringBuffer()
      ..writeln('ArchiveMe beta progress summary')
      ..writeln('')
      ..writeln(
        '${BetaActivationSummaryCopy.statusHeading}: '
        '${BetaActivationSummaryCopy.statusLabel(summary.status)}',
      )
      ..writeln('')
      ..writeln('${BetaActivationSummaryCopy.appOpens}: ${summary.appOpens}')
      ..writeln(
        '${BetaActivationSummaryCopy.recordScreenViews}: '
        '${summary.recordScreenViews}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.firstMomentSaved}: '
        '${summary.firstMomentSaved}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.secondMomentSaved}: '
        '${summary.secondMomentSaved}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.firstProofReached}: '
        '${summary.firstProofReached}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.patternsOpened}: '
        '${summary.patternsOpened}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.patternDetailsOpened}: '
        '${summary.patternDetailsOpened}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.weeklyReviewOpened}: '
        '${summary.weeklyReviewOpened}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.returnDayFlowAnswered}: '
        '${summary.returnDayFlowAnswered}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.transcriptCorrected}: '
        '${summary.transcriptCorrected}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.betaFeedbackOpened}: '
        '${summary.betaFeedbackOpened}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.betaFeedbackSubmitted}: '
        '${summary.betaFeedbackSubmitted}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.proScreenOpened}: '
        '${summary.proScreenOpened}',
      )
      ..writeln(
        '${BetaActivationSummaryCopy.restorePurchasesTapped}: '
        '${summary.restorePurchasesTapped}',
      );
    return buffer.toString().trimRight();
  }
}
