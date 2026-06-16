import 'memory_authority_frame.dart';
import 'memory_authority_framing_engine.dart';
import '../archive_packs/archive_pack_scope_policy.dart';
import 'memory_control_model.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import '../pressure_retention/pressure_check_in_record.dart';

/// Reliability classification before a memory card renders.
enum MemoryReliabilityState {
  enoughEvidence('enough_evidence'),
  lowEvidence('low_evidence'),
  mixedEvidence('mixed_evidence'),
  staleEvidence('stale_evidence'),
  crossThread('cross_thread'),
  crossPack('cross_pack'),
  blocked('blocked');

  const MemoryReliabilityState(this.id);

  final String id;

  String get label => switch (this) {
    MemoryReliabilityState.enoughEvidence => 'Enough evidence',
    MemoryReliabilityState.lowEvidence => 'Not enough evidence yet',
    MemoryReliabilityState.mixedEvidence => 'Mixed evidence',
    MemoryReliabilityState.staleEvidence => 'May be stale',
    MemoryReliabilityState.crossThread => 'Cross-thread connection',
    MemoryReliabilityState.crossPack => 'Cross-pack connection',
    MemoryReliabilityState.blocked => 'Memory off',
  };

  String? get helper => switch (this) {
    MemoryReliabilityState.lowEvidence => 'Not enough evidence yet.',
    MemoryReliabilityState.mixedEvidence =>
      'Your archive contains mixed evidence.',
    MemoryReliabilityState.staleEvidence =>
      'This may be based on older evidence.',
    MemoryReliabilityState.crossThread => 'This may connect to another thread.',
    MemoryReliabilityState.crossPack => 'This may connect to another pack.',
    _ => null,
  };
}

/// Pure reliability check from existing authority/retrieval data — no AI.
abstract class MemoryReliabilityCheck {
  MemoryReliabilityCheck._();

  static MemoryReliabilityResult classify({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    DateTime? now,
  }) {
    if (MemoryScopePolicy.scope == MemoryScope.off) {
      return const MemoryReliabilityResult(
        state: MemoryReliabilityState.blocked,
        framing: null,
      );
    }

    final framing = const MemoryAuthorityFramingEngine().frame(
      records,
      now: now,
      cardType: cardType,
    );

    if (!framing.allowsConnectionClaims) {
      final reason = framing.frame.reasonId;
      if (reason == MemoryAuthorityReason.memoryOff) {
        return MemoryReliabilityResult(
          state: MemoryReliabilityState.blocked,
          framing: framing,
        );
      }
      if (reason == MemoryAuthorityReason.mixedEvidence) {
        return MemoryReliabilityResult(
          state: MemoryReliabilityState.mixedEvidence,
          framing: framing,
        );
      }
      if (reason == MemoryAuthorityReason.olderUnreinforced ||
          reason == MemoryAuthorityReason.changedLater) {
        return MemoryReliabilityResult(
          state: MemoryReliabilityState.staleEvidence,
          framing: framing,
        );
      }
      return MemoryReliabilityResult(
        state: MemoryReliabilityState.lowEvidence,
        framing: framing,
      );
    }

    if (CrossThreadDetector.isCrossThread(framing.candidates)) {
      return MemoryReliabilityResult(
        state: MemoryReliabilityState.crossThread,
        framing: framing,
      );
    }

    if (ArchivePackScopePolicy.isCrossPack(framing.candidates) &&
        !ArchivePackScopePolicy.allowsCrossPackByPolicy(framing.candidates)) {
      return MemoryReliabilityResult(
        state: MemoryReliabilityState.crossPack,
        framing: framing,
      );
    }

    if (framing.frame.authorityState == MemoryAuthorityState.conflicting) {
      return MemoryReliabilityResult(
        state: MemoryReliabilityState.mixedEvidence,
        framing: framing,
      );
    }
    if (framing.frame.authorityState == MemoryAuthorityState.stale ||
        framing.frame.authorityState == MemoryAuthorityState.superseded) {
      return MemoryReliabilityResult(
        state: MemoryReliabilityState.staleEvidence,
        framing: framing,
      );
    }

    return MemoryReliabilityResult(
      state: MemoryReliabilityState.enoughEvidence,
      framing: framing,
    );
  }
}

class MemoryReliabilityResult {
  const MemoryReliabilityResult({required this.state, required this.framing});

  final MemoryReliabilityState state;
  final MemoryAuthorityFraming? framing;

  bool get allowsDirectClaim =>
      state == MemoryReliabilityState.enoughEvidence ||
      state == MemoryReliabilityState.mixedEvidence ||
      state == MemoryReliabilityState.staleEvidence;

  bool get requiresCrossThreadConfirmation =>
      state == MemoryReliabilityState.crossThread;

  bool get requiresCrossPackConfirmation =>
      state == MemoryReliabilityState.crossPack;
}

/// Detects when eligible records span more than one explicit archive thread.
abstract class CrossThreadDetector {
  CrossThreadDetector._();

  static bool isCrossThread(List<PressureCheckInRecord> records) {
    final threadIds = records
        .map((r) => r.archiveThreadId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return threadIds.length >= 2;
  }

  static String? primaryThreadId(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final r in records) {
      final id = r.archiveThreadId;
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
