import 'evidence_trail_clarity_model.dart';

/// Evidence trail timeline clarity copy — beta proof-first explanation only.
abstract final class EvidenceTrailClarityCopy {
  EvidenceTrailClarityCopy._();

  static const title = 'Your evidence trail';
  static const body =
      'ArchiveMe has found the first useful proof. The longer trail shows whether '
      'this pattern keeps returning, changes, fades, or needs correcting.';

  static const timelineNowLabel = 'Now';
  static const timelineNowDetail = 'First useful proof';
  static const timelineNextReturnsLabel = 'Next returns';
  static const timelineNextReturnsDetail =
      'ArchiveMe checks whether it appears again';
  static const timelineChangeLabel = 'Change';
  static const timelineChangeDetail =
      'You see whether it softens, strengthens, or fades';
  static const timelineCorrectionLabel = 'Correction';
  static const timelineCorrectionDetail =
      'You can mark anything too vague or not relevant';

  static const supportLine = 'That longer trail is what Pro keeps.';
  static const primaryCta = 'See Pro timeline';
  static const secondaryCta = 'Keep using free';
  static const feedbackPrompt = 'Is the longer trail clear?';

  static const feedbackYes = 'Yes';
  static const feedbackNotYet = 'Not yet';
  static const feedbackNeedMoreProof = 'I need more proof';

  static const timelineRows = [
    EvidenceTrailClarityTimelineRow(
      label: timelineNowLabel,
      detail: timelineNowDetail,
    ),
    EvidenceTrailClarityTimelineRow(
      label: timelineNextReturnsLabel,
      detail: timelineNextReturnsDetail,
    ),
    EvidenceTrailClarityTimelineRow(
      label: timelineChangeLabel,
      detail: timelineChangeDetail,
    ),
    EvidenceTrailClarityTimelineRow(
      label: timelineCorrectionLabel,
      detail: timelineCorrectionDetail,
    ),
  ];

  static const feedbackOptions = [
    EvidenceTrailClarityFeedbackOption.yes,
    EvidenceTrailClarityFeedbackOption.notYet,
    EvidenceTrailClarityFeedbackOption.needMoreProof,
  ];

  static String feedbackLabel(EvidenceTrailClarityFeedbackOption option) =>
      switch (option) {
        EvidenceTrailClarityFeedbackOption.yes => feedbackYes,
        EvidenceTrailClarityFeedbackOption.notYet => feedbackNotYet,
        EvidenceTrailClarityFeedbackOption.needMoreProof => feedbackNeedMoreProof,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield timelineNowLabel;
    yield timelineNowDetail;
    yield timelineNextReturnsLabel;
    yield timelineNextReturnsDetail;
    yield timelineChangeLabel;
    yield timelineChangeDetail;
    yield timelineCorrectionLabel;
    yield timelineCorrectionDetail;
    yield supportLine;
    yield primaryCta;
    yield secondaryCta;
    yield feedbackPrompt;
    yield feedbackYes;
    yield feedbackNotYet;
    yield feedbackNeedMoreProof;
  }
}
