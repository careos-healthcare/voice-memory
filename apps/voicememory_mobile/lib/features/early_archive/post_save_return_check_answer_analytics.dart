import 'early_archive_proof_analytics.dart';
import 'post_save_return_check_answer_model.dart';

/// Safe metadata analytics for the post-save return check answer — no journal text.
abstract final class PostSaveReturnCheckAnswerAnalytics {
  PostSaveReturnCheckAnswerAnalytics._();

  static void seen({
    required int entryCount,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.postSaveReturnCheckAnswerSeen(
      entryCount: entryCount,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void tapped({
    required int entryCount,
    required PostSaveReturnCheckAnswerChoice answer,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.postSaveReturnCheckAnswerTapped(
      entryCount: entryCount,
      answer: answer.analyticsValue,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }
}
