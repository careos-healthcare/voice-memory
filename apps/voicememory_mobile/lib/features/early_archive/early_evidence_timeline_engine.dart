import '../../models/journal_entry.dart';
import 'early_evidence_timeline_copy.dart';
import 'early_first_signal_engine.dart';

enum EarlyEvidenceTimelineItemKind {
  repeatConfirmed,
  triggerCaptured,
  softerReturn,
  helpfulAction,
}

class EarlyEvidenceTimelineItem {
  const EarlyEvidenceTimelineItem({
    required this.kind,
    required this.title,
    required this.body,
  });

  final EarlyEvidenceTimelineItemKind kind;
  final String title;
  final String body;
}

class EarlyEvidenceTimeline {
  const EarlyEvidenceTimeline({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<EarlyEvidenceTimelineItem> items;

  bool get showsSofterReturn => items.any(
        (item) => item.kind == EarlyEvidenceTimelineItemKind.softerReturn,
      );

  bool get showsHelpfulAction => items.any(
        (item) => item.kind == EarlyEvidenceTimelineItemKind.helpfulAction,
      );
}

abstract final class EarlyEvidenceTimelineEngine {
  EarlyEvidenceTimelineEngine._();

  static EarlyEvidenceTimeline? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
  }) {
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }

    final items = <EarlyEvidenceTimelineItem>[
      const EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.repeatConfirmed,
        title: EarlyEvidenceTimelineCopy.repeatConfirmedTitle,
        body: EarlyEvidenceTimelineCopy.repeatConfirmedBody,
      ),
    ];

    if (EarlyFirstSignalEngine.hasTriggerCaptureEvidence(
      entries: entries,
      milestoneMarked: triggerCapturedMilestone,
    )) {
      items.add(
        const EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.triggerCaptured,
          title: EarlyEvidenceTimelineCopy.triggerCapturedTitle,
          body: EarlyEvidenceTimelineCopy.triggerCapturedBody,
        ),
      );
    }

    if (EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries)) {
      items.add(
        const EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.softerReturn,
          title: EarlyEvidenceTimelineCopy.softerReturnTitle,
          body: EarlyEvidenceTimelineCopy.softerReturnBody,
        ),
      );
    }

    if (EarlyFirstSignalEngine.hasHelpfulActionEvidence(
      entries: entries,
      milestoneMarked: helpfulActionCapturedMilestone,
    )) {
      items.add(
        const EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.helpfulAction,
          title: EarlyEvidenceTimelineCopy.helpfulActionTitle,
          body: EarlyEvidenceTimelineCopy.helpfulActionBody,
        ),
      );
    }

    return EarlyEvidenceTimeline(
      title: EarlyEvidenceTimelineCopy.title,
      subtitle: EarlyEvidenceTimelineCopy.subtitle,
      items: items,
    );
  }
}
