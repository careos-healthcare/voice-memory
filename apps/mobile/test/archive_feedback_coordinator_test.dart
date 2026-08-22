import 'dart:io';

import 'package:archiveme_mobile/features/feedback/archive_feedback_coordinator.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_store.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ArchiveFeedbackStore> _store(String stamp) async {
  final path = '/tmp/vm_feedback_coord_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return ArchiveFeedbackStore(prefs);
}

void main() {
  test(
    'loadSummary returns empty when AppServices is not initialized',
    () async {
      final summary = await ArchiveFeedbackCoordinator.loadSummary();
      expect(summary, ArchiveFeedbackSummary.empty);
    },
  );

  test(
    'latestDominantIssue returns null when AppServices is not initialized',
    () async {
      final issue = await ArchiveFeedbackCoordinator.latestDominantIssue();
      expect(issue, isNull);
    },
  );

  test(
    'saveFeedback does not throw when AppServices is not initialized',
    () async {
      await ArchiveFeedbackCoordinator.saveFeedback(
        type: ArchiveFeedbackType.useful,
        targetType: ArchiveFeedbackTargetType.archiveMemory,
        targetId: 'mem1',
      );
    },
  );

  test('trackFeedbackShown does not throw', ArchiveFeedbackCoordinator.trackFeedbackShown);

  test('store-backed summary finds dominant issue after two taps', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final store = await _store(stamp);

    await store.save(
      ArchiveFeedback(
        id: 'a',
        type: ArchiveFeedbackType.tooGeneric,
        targetType: ArchiveFeedbackTargetType.checkInResult,
        createdAt: DateTime(2026, 6),
      ),
    );
    await store.save(
      ArchiveFeedback(
        id: 'b',
        type: ArchiveFeedbackType.tooGeneric,
        targetType: ArchiveFeedbackTargetType.checkInResult,
        createdAt: DateTime(2026, 6, 2),
      ),
    );

    final summary = await store.summary();
    expect(summary.dominantIssue, ArchiveFeedbackType.tooGeneric);
  });
}