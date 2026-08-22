import 'package:archiveme_mobile/features/pressure_retention/low_effort_check_in_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';

/// Turns a one-tap check-in into a real, lightweight evidence record. Pure
/// and deterministic.
///
/// Honesty rules:
/// - Only "It returned" and "It changed" assert that the tracked thread
///   actually showed up again, so only those may count as a thread
///   occurrence — and only when the dominant thread maps to a real context
///   the engines understand. "It faded" / "Not sure" save a bare entry that
///   adds to the archive without reshaping any thread.
/// - The record carries no notes, so it can never form belief-like phrases,
///   and no scores or mood labels exist anywhere on it.
class LowEffortCheckInEngine {
  const LowEffortCheckInEngine();

  static const _threadEngine = ThreadReturnEvidenceEngine();

  /// [now] and [entryId] are injectable for tests.
  PressureCheckInRecord buildRecord(
    LowEffortCheckInOption option,
    List<PressureCheckInRecord> existing, {
    DateTime? now,
    String? entryId,
  }) {
    final clock = now ?? DateTime.now();
    final contexts = <String>[];

    if (option == LowEffortCheckInOption.returned ||
        option == LowEffortCheckInOption.changed) {
      final evidence = _threadEngine.build(existing, now: clock);
      if (evidence.hasEvidence && evidence.sourceTerms.isNotEmpty) {
        final context = PressureContext.fromId(evidence.sourceTerms.first);
        if (context != null) contexts.add(context.id);
      }
    }

    return PressureCheckInRecord(
      entryId: entryId ?? 'low_effort_${clock.microsecondsSinceEpoch}',
      createdAt: clock,
      optionId: option.recordOptionId,
      contextIds: contexts,
    );
  }
}