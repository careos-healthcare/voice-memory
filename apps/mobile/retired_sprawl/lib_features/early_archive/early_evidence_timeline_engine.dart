import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_insight_quality_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_insight_quality_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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
    this.evidencePhrases = const [],
  });

  final String title;
  final String subtitle;
  final List<EarlyEvidenceTimelineItem> items;
  final List<String> evidencePhrases;

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

    final insight = EarlyArchiveInsightQualityEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(entries);

    final items = <EarlyEvidenceTimelineItem>[
      EarlyEvidenceTimelineItem(
        kind: EarlyEvidenceTimelineItemKind.repeatConfirmed,
        title: EarlyEvidenceTimelineCopy.repeatConfirmedTitle,
        body:
            insight.repeatSummary ??
            EarlyArchiveInsightQualityCopy.timelineRepeatFallback,
      ),
    ];

    if (EarlyFirstSignalEngine.hasTriggerCaptureEvidence(
      entries: entries,
      milestoneMarked: triggerCapturedMilestone,
    )) {
      items.add(
        EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.triggerCaptured,
          title: EarlyEvidenceTimelineCopy.triggerCapturedTitle,
          body:
              insight.triggerSummary ??
              EarlyArchiveInsightQualityCopy.triggerFallback,
        ),
      );
    }

    if (EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries)) {
      items.add(
        EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.softerReturn,
          title: EarlyEvidenceTimelineCopy.softerReturnTitle,
          body:
              insight.softeningSummary ??
              EarlyArchiveInsightQualityCopy.softeningFallback,
        ),
      );
    }

    if (EarlyFirstSignalEngine.hasHelpfulActionEvidence(
      entries: entries,
      milestoneMarked: helpfulActionCapturedMilestone,
    )) {
      items.add(
        EarlyEvidenceTimelineItem(
          kind: EarlyEvidenceTimelineItemKind.helpfulAction,
          title: EarlyEvidenceTimelineCopy.helpfulActionTitle,
          body:
              insight.helpfulActionSummary ??
              EarlyArchiveInsightQualityCopy.helpfulActionFallback,
        ),
      );
    }

    return EarlyEvidenceTimeline(
      title: EarlyEvidenceTimelineCopy.title,
      subtitle:
          insight.timelineSubtitle ??
          EarlyArchiveInsightQualityCopy.timelineSubtitleFallback,
      items: items,
      evidencePhrases: evidence.phrases,
    );
  }
}