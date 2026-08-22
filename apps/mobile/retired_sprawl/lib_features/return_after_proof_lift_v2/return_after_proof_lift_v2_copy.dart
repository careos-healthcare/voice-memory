import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_model.dart';

/// Return-after-proof lift v2 copy — generic watch lines only.
abstract final class ReturnAfterProofLiftV2Copy {
  ReturnAfterProofLiftV2Copy._();

  static const title = 'Come back when it happens again';
  static const body =
      'The next save is what tells ArchiveMe whether this is getting louder, softer, or fading.';
  static const primaryCta = 'Save the next return';
  static const secondaryCta = 'Remind me what to watch';
  static const dismissCta = 'Not today';

  static String watchLineFor(ReturnAfterProofWatchTargetType type) =>
      switch (type) {
        ReturnAfterProofWatchTargetType.returnedAgain =>
          'Watch for the same situation returning.',
        ReturnAfterProofWatchTargetType.feltLighter =>
          'Watch whether it feels easier next time.',
        ReturnAfterProofWatchTargetType.feltHeavier =>
          'Watch whether it feels louder next time.',
        ReturnAfterProofWatchTargetType.helpedAgain =>
          'Watch whether the helpful action works again.',
        ReturnAfterProofWatchTargetType.handledDifferently =>
          'Watch whether this is still background or active again.',
        ReturnAfterProofWatchTargetType.avoidedAgain =>
          'Watch for the next moment that feels connected.',
        ReturnAfterProofWatchTargetType.notCurrent =>
          'Watch whether this is still background or active again.',
      };

  static const fallbackWatchLine =
      'Watch for the next moment that feels connected.';
}

enum ReturnAfterProofLiftV2ActionType { saveNextReturn, expandWatch, dismiss }

extension ReturnAfterProofLiftV2ActionTypeStorage
    on ReturnAfterProofLiftV2ActionType {
  String get analyticsValue => switch (this) {
    ReturnAfterProofLiftV2ActionType.saveNextReturn => 'save_next_return',
    ReturnAfterProofLiftV2ActionType.expandWatch => 'expand_watch',
    ReturnAfterProofLiftV2ActionType.dismiss => 'dismiss',
  };
}