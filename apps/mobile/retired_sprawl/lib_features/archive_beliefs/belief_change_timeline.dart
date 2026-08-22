import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';

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
          statement: _sentenceCase(c.title),
          detail: c.detail,
          sortOrder: order++,
        ),
      );
    }
    for (final c in feed.weakened) {
      items.add(
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.weakening,
          statement: _sentenceCase(c.title),
          detail: c.detail,
          sortOrder: order++,
        ),
      );
    }
    for (final c in feed.newItems) {
      items.add(
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.newBelief,
          statement: _sentenceCase(c.title),
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

/// Sentence case, not title case. Themes arrive lowercased from
/// `DiscoverLocalEngine.themeCounts`, so the first letter is raised for
/// readability — but Title Case Like This reads as a headline or a quotation,
/// and these are themes ArchiveMe derived rather than anything the user said.
String _sentenceCase(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return '${t[0].toUpperCase()}${t.substring(1)}';
}