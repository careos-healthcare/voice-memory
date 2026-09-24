/// Copy for the internal activation drop-off review — debug only.
abstract final class ActivationDropoffReviewCopy {
  ActivationDropoffReviewCopy._();

  static const title = 'Activation drop-off';

  static const bottleneckLabel = 'Current bottleneck';

  static const bottleneckFirstMomentSaved =
      'Users are not saving the first moment yet.';
  static const bottleneckSecondMomentSaved =
      'Users are not returning for the second moment yet.';
  static const bottleneckFirstProofReached =
      'Users are not reaching first proof yet.';
  static const bottleneckReturnedAfterFirstProof =
      'Users are not returning after first proof yet.';
  static const bottleneckReturnCheckAnswered =
      'Users are not answering the return check yet.';
  static const bottleneckProTapped = 'Users are not tapping Pro yet.';
  static const bottleneckNone = 'No critical bottleneck in the early loop.';

  static const rowAppOpened = 'App opened';
  static const rowFirstUsePromptSeen = 'First-use prompt seen';
  static const rowFirstMomentSaved = 'First moment saved';
  static const rowReturnedAfterFirstMoment = 'Returned after first moment';
  static const rowSecondMomentSaved = 'Second moment saved';
  static const rowFirstProofReached = 'First proof reached';
  static const rowReturnedAfterFirstProof = 'Returned after first proof';
  static const rowFourthMomentSaved = 'Fourth moment saved';
  static const rowReturnCheckAnswered = 'Return check answered';
  static const rowProBoundarySeen = 'Pro boundary seen';
  static const rowProTapped = 'Pro tapped';
}
