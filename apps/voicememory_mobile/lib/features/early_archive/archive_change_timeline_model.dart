import 'archive_change_timeline_copy.dart';

enum ArchiveChangeTimelineItemKind {
  firstSeen,
  repeated,
  lookedSofter,
  lookedStronger,
  aboutTheSame,
  changedThisTime,
  helpfulActionAppeared,
  stillWatching,
}

class ArchiveChangeTimelineItem {
  const ArchiveChangeTimelineItem({
    required this.kind,
    required this.label,
    required this.body,
    this.phrase,
  });

  final ArchiveChangeTimelineItemKind kind;
  final String label;
  final String body;
  final String? phrase;

  bool get hasPhrase => phrase != null && phrase!.trim().isNotEmpty;
}

class ArchiveChangeTimeline {
  const ArchiveChangeTimeline({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<ArchiveChangeTimelineItem> items;

  bool get hasContent => items.isNotEmpty;

  List<String> get visibleCopyBlocks => [
        title,
        subtitle,
        for (final item in items) ...[
          item.label,
          item.body,
          if (item.hasPhrase) item.phrase!,
        ],
      ];

  static const expectedLabelOrder = [
    ArchiveChangeTimelineCopy.firstSeenLabel,
    ArchiveChangeTimelineCopy.repeatedLabel,
    ArchiveChangeTimelineCopy.lookedSofterLabel,
    ArchiveChangeTimelineCopy.lookedStrongerLabel,
    ArchiveChangeTimelineCopy.aboutTheSameLabel,
    ArchiveChangeTimelineCopy.changedThisTimeLabel,
    ArchiveChangeTimelineCopy.helpfulActionAppearedLabel,
    ArchiveChangeTimelineCopy.stillWatchingLabel,
  ];
}
