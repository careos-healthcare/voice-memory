import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Copy for the Archive Home send-choice entry and the post-save card that
/// replaces a skipped remote reflection.
///
/// The title is the imperative form of
/// [PrivacyClaimCatalogue.onDeviceByDefaultHeading]. The subtitle reuses the
/// privacy card heading so the two surfaces name the same choice.
abstract final class RemoteProcessingChoiceCopy {
  RemoteProcessingChoiceCopy._();

  static const String chooseWhatLeavesTitle =
      PrivacyClaimCatalogue.chooseWhatLeavesYourPhone;

  static const String whereWordsGoSubtitle =
      PrivacyScreenCopy.whereWordsGoTitle;

  /// Replaces a silent omit of the reflection/analysis card when remote
  /// processing is off.
  ///
  /// Not "You turned off": default is off, so that would be false for anyone
  /// who never granted it. Not "shown below": the live receipt has no pattern
  /// badges under it. The second sentence states the architecture that
  /// [PrivacyScreenCopy.whereWordsGoTitle] already documents — badges are
  /// local Dart over local text.
  ///
  /// Scoped with "until you turn it on in Privacy" so the send claim names
  /// the control.
  static const String skippedNote =
      'Remote processing is off, so this moment was not sent for a deeper '
      'read — comparing it to what you have said before — until you turn it '
      'on in Privacy. Local pattern badges still use what is already on this '
      'phone.';

  static const List<String> all = [
    chooseWhatLeavesTitle,
    whereWordsGoSubtitle,
    skippedNote,
  ];
}
