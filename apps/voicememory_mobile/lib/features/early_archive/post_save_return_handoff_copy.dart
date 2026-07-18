/// Copy for the post-save return handoff after entry 1 or 2.
import '../trust/capture_recovery_copy.dart';

abstract final class PostSaveReturnHandoffCopy {
  PostSaveReturnHandoffCopy._();

  static const afterFirstSaveTitle = 'Come back when this shows up again.';

  static const afterFirstSaveBodyFallback =
      'If it returns, changes, fades, or disappears, save that moment too.';

  static const afterFirstSaveFooter = 'Short is fine.';

  static const afterSecondSaveRelatedTitle = 'One more unlocks first proof';

  static const afterSecondSaveRelatedBodyFallback =
      'One more related moment unlocks first proof.';

  static const afterSecondSaveRelatedFooter =
      '2 of 3 · Ten seconds is enough.';

  static const afterSecondSaveUnrelatedTitle = 'Keep recording real moments';

  static const afterSecondSaveUnrelatedBody = CaptureRecoveryCopy.noClearMatchYet;

  static const afterSecondSaveUnrelatedFooter = 'No need to force a pattern.';

  static String afterFirstSaveBodyWithPhrase(String phrase) =>
      'Come back when “$phrase” shows up again and record what happened.';

  static String afterSecondSaveRelatedBodyWithPhrase(String phrase) =>
      'Record one more moment like “$phrase”. That unlocks your first proof.';
}
