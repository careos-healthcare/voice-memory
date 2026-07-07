import 'shareable_proof_copy.dart';

/// Fixed share templates — generic marketing copy only.
enum ShareableProofTemplate {
  keepsReturning(
    id: 'keeps_returning',
    label: 'Keeps returning',
    text: ShareableProofCopy.templateKeepsReturning,
  ),
  chatGptDifferentiation(
    id: 'chatgpt_differentiation',
    label: 'Timeline vs chat',
    text: ShareableProofCopy.templateChatGptDifferentiation,
  ),
  trackingTimeline(
    id: 'tracking_timeline',
    label: 'Tracking timeline',
    text: ShareableProofCopy.templateTrackingTimeline,
  );

  const ShareableProofTemplate({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;

  static ShareableProofTemplate get defaultTemplate => keepsReturning;
}

/// Session latch for proof/report cards the user has already seen.
class ShareableProofSeenLatch {
  ShareableProofSeenLatch._();

  static var timelineProofMomentSeen = false;
  static var betaTesterReportSeen = false;

  static void markTimelineProofMomentSeen() {
    timelineProofMomentSeen = true;
  }

  static void markBetaTesterReportSeen() {
    betaTesterReportSeen = true;
  }

  static void resetForTest() {
    timelineProofMomentSeen = false;
    betaTesterReportSeen = false;
  }
}

class ShareableProofVisibilityInput {
  const ShareableProofVisibilityInput({
    required this.entryCount,
    required this.timelineProofMomentSeen,
    required this.betaTesterReportSeen,
    required this.isRecording,
    required this.isDegradedTranscript,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
  });

  final int entryCount;
  final bool timelineProofMomentSeen;
  final bool betaTesterReportSeen;
  final bool isRecording;
  final bool isDegradedTranscript;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}

class ShareableProofResult {
  const ShareableProofResult({
    required this.shouldShow,
    required this.entryCount,
    required this.hasTimelineProof,
    this.selectedTemplate = ShareableProofTemplate.keepsReturning,
  });

  factory ShareableProofResult.hidden({required int entryCount}) =>
      ShareableProofResult(
        shouldShow: false,
        entryCount: entryCount,
        hasTimelineProof: false,
      );

  final bool shouldShow;
  final int entryCount;
  final bool hasTimelineProof;
  final ShareableProofTemplate selectedTemplate;

  String shareTextFor(ShareableProofTemplate template) {
    final body = [
      template.text,
      ShareableProofCopy.privacyWarning,
    ].join('\n');
    assert(ShareableProofCopy.isSafeShareText(body));
    return body;
  }

  String get defaultShareText => shareTextFor(selectedTemplate);
}
