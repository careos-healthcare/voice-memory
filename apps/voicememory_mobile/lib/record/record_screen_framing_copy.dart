import '../product/consumer_ui_copy.dart';
import '../security/privacy_copy_policy.dart';

/// Idle framing on the Record tab.
abstract class RecordScreenFramingCopy {
  RecordScreenFramingCopy._();

  static const String title = ConsumerUiCopy.recordTitle;
  static const String guidance = ConsumerUiCopy.recordSubtitle;
  static const String helperLine = '';

  /// True empty archive — count 0 only.
  static const String emptyArchiveTitle = 'Your archive is empty';
  static const String emptyArchiveBody =
      'Record short moments. ArchiveMe spots what repeats.';
  static const String emptyArchiveFootnote =
      'Nothing is analysed until you save something.';

  /// First-run privacy reassurance — count 0 only, under the empty archive card.
  static const String firstRunPrivacyTitle = 'Before you record';
  static const String firstRunPrivacyBody =
      PrivacyCopyPolicy.personalNotMedicalDisclaimer;
  static const String firstRunPrivacyLink = 'How it works';

  /// Low-friction pressure wedge under the first-use capture block.
  static const String firstUsePressureMomentLink =
      'Or start with: a pressure moment';

  /// One saved moment — calm started state, no pattern claims.
  static const String archiveStartedTitle = 'Archive started';
  static const String archiveStartedBody =
      'ArchiveMe needs a second moment before it can compare what repeats.';
  static const String archiveStartedCta = 'Add one more moment';

  /// Two–three entries without a grounded repeat yet.
  static const String weakCompareBody =
      'Add one more moment so ArchiveMe can compare the behaviour, not just the words.';
  static const String weakCompareFootnote =
      'Nothing is guessed. Patterns only appear when your own words support them.';

  /// Must not appear on Record at entry count 0 or 1 (first impression).
  static const List<String> bannedFirstImpressionPhrases = [
    'Ready to record',
    'Start your archive',
    'Notice what repeats',
    'Watch what changes',
    'ArchiveMe is starting to notice',
    'Each moment helps ArchiveMe remember the pattern',
    'starting to notice',
  ];
}
