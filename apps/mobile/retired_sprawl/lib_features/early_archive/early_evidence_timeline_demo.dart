import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_demo_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_engine.dart';

/// Static sample timeline for first-time Patterns preview — no journal writes.
abstract final class EarlyEvidenceTimelineDemo {
  EarlyEvidenceTimelineDemo._();

  static const timeline = EarlyEvidenceTimeline(
    title: EarlyEvidenceTimelineDemoCopy.title,
    subtitle: EarlyEvidenceTimelineDemoCopy.subtitle,
    items: [
      EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.repeatConfirmed,
        title: EarlyEvidenceTimelineDemoCopy.repeatConfirmedTitle,
        body: EarlyEvidenceTimelineDemoCopy.repeatConfirmedBody,
      ),
      EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.triggerCaptured,
        title: EarlyEvidenceTimelineDemoCopy.triggerCapturedTitle,
        body: EarlyEvidenceTimelineDemoCopy.triggerCapturedBody,
      ),
      EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.softerReturn,
        title: EarlyEvidenceTimelineDemoCopy.softerReturnTitle,
        body: EarlyEvidenceTimelineDemoCopy.softerReturnBody,
      ),
      EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.helpfulAction,
        title: EarlyEvidenceTimelineDemoCopy.helpfulActionTitle,
        body: EarlyEvidenceTimelineDemoCopy.helpfulActionBody,
      ),
    ],
  );

  /// Empty or first-entry Patterns only — real timeline takes priority.
  static bool canShowCta({
    required int entryCount,
    required bool hasRealTimeline,
  }) => !hasRealTimeline && (entryCount == 0 || entryCount == 1);
}