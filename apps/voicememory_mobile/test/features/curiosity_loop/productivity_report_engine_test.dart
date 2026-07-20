import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/models/curiosity_reaction_record.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/productivity_report_engine.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';

CuriosityReactionRecord _record({
  required String id,
  required DateTime timestamp,
  required YesterdaysSnapshotReaction reactionType,
  required String primaryAnchor,
}) {
  return CuriosityReactionRecord(
    id: id,
    hookId: 'hook_$id',
    timestamp: timestamp,
    reactionType: reactionType,
    primaryAnchor: primaryAnchor,
    hookType: CuriosityHookType.blocker,
  );
}

void main() {
  group('ProductivityReportEngine', () {
    test('returns empty aggregates when no reactions exist in the window', () async {
      final relativeTo = DateTime.utc(2026, 6, 18, 12);
      final repository = InMemoryCuriosityReactionRepository([
        _record(
          id: 'old',
          timestamp: relativeTo.subtract(const Duration(days: 8)),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
      ]);
      final engine = ProductivityReportEngine(repository);

      final report = await engine.generateWeeklyReport(relativeTo: relativeTo);

      expect(report.totalReactions, 0);
      expect(report.reactionBreakdown, isEmpty);
      expect(report.stuckAnchors, isEmpty);
      expect(report.momentumAnchors, isEmpty);
    });

    test('calculates reaction percentages for the rolling seven-day window', () async {
      final relativeTo = DateTime.utc(2026, 6, 18, 12);
      final repository = InMemoryCuriosityReactionRepository([
        _record(
          id: 'r1',
          timestamp: DateTime.utc(2026, 6, 18, 10),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'finished the draft',
        ),
        _record(
          id: 'r2',
          timestamp: DateTime.utc(2026, 6, 17, 10),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'finished the draft',
        ),
        _record(
          id: 'r3',
          timestamp: DateTime.utc(2026, 6, 16, 10),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'shipped the fix',
        ),
        _record(
          id: 'r4',
          timestamp: DateTime.utc(2026, 6, 15, 10),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
        _record(
          id: 'r5',
          timestamp: DateTime.utc(2026, 6, 14, 10),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'avoided the conversation',
        ),
        _record(
          id: 'r6',
          timestamp: DateTime.utc(2026, 6, 13, 10),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
        _record(
          id: 'r7',
          timestamp: DateTime.utc(2026, 6, 12, 10),
          reactionType: YesterdaysSnapshotReaction.pivot,
          primaryAnchor: 'changed the plan',
        ),
        _record(
          id: 'outside_window',
          timestamp: DateTime.utc(2026, 6, 11, 11, 59),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'outside window',
        ),
      ]);
      final engine = ProductivityReportEngine(repository);

      final report = await engine.generateWeeklyReport(relativeTo: relativeTo);

      expect(report.totalReactions, 7);
      expect(report.reactionBreakdown['progressed'], closeTo(3 / 7, 0.0001));
      expect(report.reactionBreakdown['stuck'], closeTo(3 / 7, 0.0001));
      expect(report.reactionBreakdown['pivot'], closeTo(1 / 7, 0.0001));
      expect(
        report.reactionBreakdown.values.fold<double>(0, (sum, value) => sum + value),
        closeTo(1.0, 0.0001),
      );
    });

    test('ranks stuck and momentum anchors by frequency', () async {
      final relativeTo = DateTime.utc(2026, 6, 18, 12);
      final repository = InMemoryCuriosityReactionRepository([
        _record(
          id: 's1',
          timestamp: DateTime.utc(2026, 6, 18, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
        _record(
          id: 's2',
          timestamp: DateTime.utc(2026, 6, 17, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
        _record(
          id: 's3',
          timestamp: DateTime.utc(2026, 6, 16, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
        ),
        _record(
          id: 's4',
          timestamp: DateTime.utc(2026, 6, 15, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'avoided the conversation',
        ),
        _record(
          id: 's5',
          timestamp: DateTime.utc(2026, 6, 14, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'avoided the conversation',
        ),
        _record(
          id: 's6',
          timestamp: DateTime.utc(2026, 6, 13, 9),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'late nights',
        ),
        _record(
          id: 'm1',
          timestamp: DateTime.utc(2026, 6, 18, 8),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'finished the draft',
        ),
        _record(
          id: 'm2',
          timestamp: DateTime.utc(2026, 6, 17, 8),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'finished the draft',
        ),
        _record(
          id: 'm3',
          timestamp: DateTime.utc(2026, 6, 16, 8),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'shipped the fix',
        ),
        _record(
          id: 'm4',
          timestamp: DateTime.utc(2026, 6, 15, 8),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'shipped the fix',
        ),
      ]);
      final engine = ProductivityReportEngine(repository);

      final report = await engine.generateWeeklyReport(relativeTo: relativeTo);

      expect(report.stuckAnchors, [
        'said yes again',
        'avoided the conversation',
        'late nights',
      ]);
      expect(report.momentumAnchors, [
        'finished the draft',
        'shipped the fix',
      ]);
    });
  });
}
