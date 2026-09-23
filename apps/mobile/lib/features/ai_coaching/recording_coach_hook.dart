import 'dart:async';

import 'package:archiveme_mobile/features/ai_coaching/coach_action_plan.dart';
import 'package:archiveme_mobile/features/ai_coaching/coach_action_store.dart';
import 'package:sqflite/sqflite.dart';

/// Generates action items as soon as a recording's transcript is ready.
abstract final class RecordingCoachHook {
  static CoachActionStore? store;

  static void bind(Database database) {
    store = CoachActionStore(database);
  }

  static Future<void> onTranscriptReady(
    String transcript, {
    String? entryId,
    int durationSeconds = 0,
  }) async {
    final id = entryId?.trim() ?? '';
    final destination = store;
    if (id.isEmpty || destination == null) return;
    final items = CoachActionPlan.fromTranscript(
      transcript,
      durationSeconds: durationSeconds,
    );
    await destination.replaceForEntry(entryId: id, items: items);
  }
}
