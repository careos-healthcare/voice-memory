import 'dart:async';

import 'hook_diagnosis_model.dart';
import 'hook_diagnosis_store.dart';

/// Non-blocking hook diagnosis events for trial learning.
abstract class HookDiagnosisTracker {
  HookDiagnosisTracker._();

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  static Future<void> _append({
    required String type,
    String? checkInId,
    String? reason,
    String? rating,
    Map<String, String> metadata = const {},
  }) async {
    await _safe(() async {
      final event = HookDiagnosisEvent(
        id: 'hd_${DateTime.now().microsecondsSinceEpoch}',
        createdAt: DateTime.now(),
        type: type,
        checkInId: checkInId,
        reason: reason,
        rating: rating,
        metadata: metadata,
      );
      await HookDiagnosisStore.instance().append(event);
    });
  }

  static void trackCheckInQuestionRated({
    required String checkInId,
    required String rating,
  }) {
    unawaited(
      _append(
        type: HookDiagnosisEventType.checkInQuestionRated,
        checkInId: checkInId,
        rating: rating,
      ),
    );
  }

  static void trackCheckInResultRated({
    required String checkInId,
    required String rating,
  }) {
    unawaited(
      _append(
        type: HookDiagnosisEventType.checkInResultRated,
        checkInId: checkInId,
        rating: rating,
      ),
    );
  }

  static void trackMissedReason({
    required String checkInId,
    required String reason,
  }) {
    unawaited(
      _append(
        type: HookDiagnosisEventType.checkInMissedReason,
        checkInId: checkInId,
        reason: reason,
      ),
    );
    if (reason == HookDiagnosisMissedReason.confusing) {
      trackConfusing(checkInId);
    }
  }

  static void trackConfusing(String checkInId) {
    unawaited(
      _append(
        type: HookDiagnosisEventType.checkInConfusing,
        checkInId: checkInId,
      ),
    );
  }

  static void trackCheckInResultNotUsefulReason({
    required String checkInId,
    required String reason,
  }) {
    unawaited(
      _append(
        type: HookDiagnosisEventType.checkInResultNotUsefulReason,
        checkInId: checkInId,
        reason: reason,
      ),
    );
  }
}
