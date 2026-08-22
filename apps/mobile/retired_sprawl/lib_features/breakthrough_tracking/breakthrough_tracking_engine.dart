import 'package:archiveme_mobile/features/archive_theory/theory_tracker_engine.dart';
import 'package:archiveme_mobile/features/breakthrough_tracking/breakthrough_shift_detector.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_models.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_summary_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Reactivated breakthrough-tracking — detects high-signal archive shifts.
abstract final class BreakthroughTrackingEngine {
  BreakthroughTrackingEngine._();

  static const confidenceDeltaThreshold = 10;

  static BreakthroughShift? detectFromMovement(SessionMovementSummaryView? summary) {
    if (summary == null) return null;
    if (!BreakthroughShiftDetector.isBreakthroughSummary(summary)) {
      return null;
    }
    return BreakthroughShift(
      headline: summary.headline,
      detailLine: summary.detailLine,
      theoryId: summary.theoryId,
      movementKind: summary.kind,
    );
  }

  static Future<BreakthroughShift?> detectAfterSave({
    required List<JournalEntry> entriesAfter,
    required String newEntryId,
    MobilePrefsStore? prefs,
  }) async {
    if (!AppServices.isInitialized && prefs == null) return null;
    final store = prefs ?? AppServices.instance.prefs;
    final snapshots = TheorySnapshotStore(store);
    final movement = await const SessionMovementSummaryEngine().build(
      entriesAfter: entriesAfter,
      newEntryId: newEntryId,
      snapshots: snapshots,
    );
    return detectFromMovement(movement);
  }
}

class BreakthroughShift {
  const BreakthroughShift({
    required this.headline,
    required this.movementKind, this.detailLine,
    this.theoryId,
  });

  final String headline;
  final String? detailLine;
  final String? theoryId;
  final SessionMovementKind movementKind;
}