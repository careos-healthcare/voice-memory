import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:archiveme_mobile/features/v1_interface/progressive_evidence_state_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// Idle framing on the Record tab.
abstract class RecordScreenFramingCopy {
  RecordScreenFramingCopy._();

  static String get title => ConsumerUiCopy.recordTitle;
  static String get guidance => ConsumerUiCopy.recordSubtitle;
  static const String helperLine = '';

  /// True empty archive — count 0 only.
  static String get emptyArchiveTitle => BetaImprovementPackEngine.recordTitle(
    entryCount: 0,
    fallback: 'Save one real moment.',
  );
  static String get emptyArchiveBody => BetaImprovementPackEngine.recordBody(
    entryCount: 0,
    fallback: ProgressiveEvidenceStateCopy.zeroBody,
  );
  static const String emptyArchiveFootnote = 'Ten seconds is enough.';

  /// Demo archive entry on Record first use.
  static const String seeExampleLink = 'See an example';

  @Deprecated('Use seeExampleLink')
  static const String seeExampleFirstLink = seeExampleLink;

  /// First-run privacy reassurance — count 0 only, under the empty archive card.
  static const String firstRunPrivacyTitle = 'Before you record';
  static const String firstRunPrivacyBody =
      PrivacyCopyPolicy.personalNotMedicalDisclaimer;
  static const String firstRunPrivacyLink = 'How it works';

  /// Low-friction pressure wedge under the first-use capture block.
  static const String firstUsePressureMomentLink =
      'Or start with: a pressure moment';

  /// One saved moment — calm started state, no pattern claims.
  static const String archiveStartedTitle =
      ProgressiveEvidenceStateCopy.oneTitle;
  static const String archiveStartedBody = ProgressiveEvidenceStateCopy.oneBody;
  static const String archiveStartedCta = 'Add one more moment';

  /// Two–three entries without a grounded repeat yet.
  static const String weakCompareBody = ProgressiveEvidenceStateCopy.twoBody;
  static const String weakCompareFootnote =
      'Not chat history — patterns only appear when your own words repeat.';

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

/// Concrete first-use recording guidance inside the capture block.
abstract final class RecordFirstUsePromptCopy {
  RecordFirstUsePromptCopy._();

  static String get title => BetaImprovementPackEngine.recordTitle(
    entryCount: 0,
    fallback: 'Save one real moment.',
  );

  static String get body => BetaImprovementPackEngine.recordBody(
    entryCount: 0,
    fallback: ProgressiveEvidenceStateCopy.zeroBody,
  );

  static const examplesHeading = 'Examples';

  static const examples = [
    'I kept checking even after I was done.',
    'I avoided replying again.',
    'I felt pressure before starting.',
  ];

  static const footer = '1 of 3 · Ten seconds is enough.';
}

/// Calm first-run promise on Record — entry count 0, simplified layout only.
abstract final class RecordFirstRunPromiseCopy {
  RecordFirstRunPromiseCopy._();

  static const String title = VisibleArchiveProofCopy.firstRunRecordTitle;
  static const String body = VisibleArchiveProofCopy.firstRunRecordBody;
  static const String supportingLine =
      VisibleArchiveProofCopy.firstRunRecordSupportingLine;
  static const proLine =
      'Free shows the first useful repeat. Pro keeps the longer trail.';
}