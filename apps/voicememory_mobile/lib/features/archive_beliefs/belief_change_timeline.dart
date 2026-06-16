import '../discover/discover_local.dart';
import 'archive_belief_models.dart';

import '../../product/belief_product_copy.dart';

enum BeliefChangeKind { strengthening, weakening, newBelief, shifting }

extension BeliefChangeNarrative on BeliefChangeTimelineItem {
  String get narrativeHeadline => switch (kind) {
    BeliefChangeKind.strengthening => BeliefProductCopy.narrativeStrengthening,
    BeliefChangeKind.weakening => BeliefProductCopy.narrativeWeakening,
    BeliefChangeKind.newBelief => BeliefProductCopy.narrativeEmerging,
    BeliefChangeKind.shifting => BeliefProductCopy.narrativeShifting,
  };
}

class BeliefChangeTimelineItem {
  const BeliefChangeTimelineItem({
    required this.kind,
    required this.statement,
    required this.detail,
    required this.sortOrder,
  });

  final BeliefChangeKind kind;
  final String statement;
  final String detail;
  final int sortOrder;
}

/// Timeline rows for Archive "beliefs changing" + Changes tab.
List<BeliefChangeTimelineItem> buildBeliefChangeTimeline({
  required ArchiveBeliefsSnapshot snapshot,
  DiscoverLocalFeed? feed,
}) {
  final items = <BeliefChangeTimelineItem>[];
  var order = 0;

  if (feed != null && feed.hasBaseline) {
    for (final c in feed.strengthened) {
      items.add(
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.strengthening,
          statement: _title(c.title),
          detail: c.detail,
          sortOrder: order++,
        ),
      );
    }
    for (final c in feed.weakened) {
      items.add(
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.weakening,
          statement: _title(c.title),
          detail: c.detail,
          sortOrder: order++,
        ),
      );
    }
    for (final c in feed.newItems) {
      items.add(
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.newBelief,
          statement: _title(c.title),
          detail: c.detail,
          sortOrder: order++,
        ),
      );
    }
  }

  for (final b in snapshot.changing) {
    if (items.any((i) => i.statement == b.statement)) continue;
    items.add(
      BeliefChangeTimelineItem(
        kind: BeliefChangeKind.shifting,
        statement: b.statement,
        detail: b.whyExplanation,
        sortOrder: order++,
      ),
    );
  }

  for (final b in snapshot.emerging) {
    if (items.length >= 8) break;
    if (items.any((i) => i.statement == b.statement)) continue;
    items.add(
      BeliefChangeTimelineItem(
        kind: BeliefChangeKind.newBelief,
        statement: b.statement,
        detail: b.whyExplanation,
        sortOrder: order++,
      ),
    );
  }

  return items;
}

String _title(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
