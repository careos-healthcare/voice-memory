import 'package:flutter/foundation.dart';

import '../archive_packs/archive_pack_scope_policy.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_retrieval_policy.dart';
import 'memory_connection_rules.dart';
import 'memory_control_model.dart';
import 'memory_priority_decision.dart';
import 'not_important_feedback.dart';
import 'wrong_thread_feedback.dart';

/// Deterministic priority scoring for archive evidence — internal only.
abstract class MemoryPriorityScore {
  MemoryPriorityScore._();

  static const int oldOneOffDays = 14;
  static const int recentDays = 7;
  static const int repeatedGroupCount = 3;

  static int scoreRecord(
    PressureCheckInRecord record, {
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> candidates,
    required DateTime anchor,
  }) {
    var score = 0;

    if (record.connectionApproved ||
        MemoryConnectionRules.isConfirmed(cardType.id)) {
      score += 1000;
    }

    final explicitThread = WrongThreadFeedback.explicitThreadFor(cardType);
    if (explicitThread != null && record.archiveThreadId == explicitThread) {
      score += 200;
    }

    final anchorPack = ArchivePackScopePolicy.primaryPackId(candidates);
    if (anchorPack != null && record.archivePackId == anchorPack) {
      score += 150;
    }

    final ageDays = anchor.difference(record.createdAt).inDays;
    if (ageDays <= recentDays) score += 80;
    if (ageDays >= oldOneOffDays) score -= 60;

    if (record.isPinned) score += 25;
    if (record.keepExactDetails) score += 25;

    if (NotImportantFeedback.isDemoted(cardType, entryId: record.entryId)) {
      score -= 500;
    }
    if (ArchiveRetrievalPolicy.isRecordNotQuite(record.entryId)) {
      score -= 120;
    }

    return score;
  }

  static int distinctEvidenceGroups(List<PressureCheckInRecord> records) {
    final keys = <String>{};
    for (final record in records) {
      if (record.keepExactDetails) {
        keys.add('exact|${record.entryId}');
        continue;
      }
      final contexts = [...record.contextIds]..sort();
      final note = '${record.fear ?? ''} ${record.stopCostNote ?? ''}'
          .trim()
          .toLowerCase();
      final day =
          '${record.createdAt.year}-${record.createdAt.month}-'
          '${record.createdAt.day}';
      keys.add('$day|${record.optionId}|${contexts.join(',')}|$note');
    }
    return keys.length;
  }

  static bool isOldOneOff(
    List<PressureCheckInRecord> candidates, {
    required DateTime anchor,
  }) {
    if (distinctEvidenceGroups(candidates) > 1) return false;
    if (candidates.isEmpty) return false;
    final newest = candidates.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    return anchor.difference(newest.createdAt).inDays >= oldOneOffDays;
  }

  static List<PressureCheckInRecord> rankedCandidates(
    List<PressureCheckInRecord> candidates, {
    required MemoryCardType cardType,
    required DateTime anchor,
  }) {
    final ranked = [...candidates]
      ..sort(
        (a, b) =>
            scoreRecord(
              b,
              cardType: cardType,
              candidates: candidates,
              anchor: anchor,
            ).compareTo(
              scoreRecord(
                a,
                cardType: cardType,
                candidates: candidates,
                anchor: anchor,
              ),
            ),
      );
    return ranked;
  }
}

/// Session log of the latest priority decision per card — ids only.
abstract class MemoryPriorityDecisionLog {
  MemoryPriorityDecisionLog._();

  static final Map<String, MemoryPriorityDecision> _lastByCard =
      <String, MemoryPriorityDecision>{};

  static void record(MemoryCardType cardType, MemoryPriorityDecision decision) {
    _lastByCard[cardType.id] = decision;
  }

  static MemoryPriorityDecision? lastFor(MemoryCardType cardType) =>
      _lastByCard[cardType.id];

  static void clear() => _lastByCard.clear();

  @visibleForTesting
  static void resetForTest() => clear();
}
