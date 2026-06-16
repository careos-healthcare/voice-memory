import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_retrieval_engine.dart';
import 'archive_retrieval_score.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// Central retrieval policy: the single gate every memory engine passes
/// through before building a connection claim from archive records.
///
/// Order of authority — retrieval never overrides Memory Scope Controls:
/// 1. [MemoryScopePolicy] decides eligibility (off / treat-as-new /
///    ask approvals / thread-only markers). Ineligible records are never
///    scored at all; memory off returns empty results, full stop.
/// 2. Session "not related" record marks are excluded.
/// 3. [ArchiveRetrievalEngine] ranks what is left and keeps only the top
///    relevant few.
/// 4. Weak-only results back no connection claims — engines render only
///    from possible-band retrieval, and "strong" still needs the
///    evidence engine itself.
abstract class ArchiveRetrievalPolicy {
  ArchiveRetrievalPolicy._();

  static const ArchiveRetrievalEngine _engine = ArchiveRetrievalEngine();

  /// Session usage signals — entry ids only, never content. Nothing here
  /// is persisted or alters saved records.
  static final Set<String> _notRelatedEntryIds = <String>{};
  static final Set<String> _usefulEntryIds = <String>{};
  static final Set<String> _notQuiteEntryIds = <String>{};

  /// Analytics dedup per event + card type for this session, so engine
  /// rebuilds never spam.
  static final Set<String> _trackedThisSession = <String>{};

  /// "Not related" on a specific record: excluded from retrieval for the
  /// rest of the session. The record itself stays untouched.
  static void markRecordNotRelated(String entryId) {
    _notRelatedEntryIds.add(entryId);
  }

  /// Useful feedback tied to a specific record raises its score slightly.
  static void markRecordUseful(String entryId) {
    _usefulEntryIds.add(entryId);
  }

  /// "Not quite" feedback tied to a specific record lowers its score.
  static void markRecordNotQuite(String entryId) {
    _notQuiteEntryIds.add(entryId);
  }

  /// Whether this record carries a "not quite" mark this session — the
  /// authority framing layer reads this as a mixed-evidence signal.
  static bool isRecordNotQuite(String entryId) =>
      _notQuiteEntryIds.contains(entryId);

  /// Scored retrieval over the scope-eligible records. Returns an empty
  /// result when memory is off or nothing relevant remains.
  static ArchiveRetrievalResult retrieve(
    List<PressureCheckInRecord> records, {
    DateTime? now,
    String? cardType,
  }) {
    // Memory Scope Controls always win: off, treat-as-new, unapproved
    // ask-mode entries, and thread-only linkage are settled before any
    // scoring happens.
    final eligible = MemoryScopePolicy.connectionEligible(
      records,
    ).where((r) => !_notRelatedEntryIds.contains(r.entryId)).toList();
    if (eligible.isEmpty) {
      _track(
        ActivationFunnelAnalytics.archiveRetrievalEmpty,
        band: ArchiveRetrievalBand.none,
        recordCount: 0,
        cardType: cardType,
      );
      return const ArchiveRetrievalResult.empty();
    }

    final result = _engine.score(
      eligible,
      now: now,
      usefulEntryIds: _usefulEntryIds,
      notQuiteEntryIds: _notQuiteEntryIds,
    );

    _track(
      ActivationFunnelAnalytics.archiveRetrievalScored,
      band: result.band,
      recordCount: result.scores.length,
      cardType: cardType,
    );
    _track(
      result.isEmpty
          ? ActivationFunnelAnalytics.archiveRetrievalEmpty
          : ActivationFunnelAnalytics.archiveRetrievalUsed,
      band: result.band,
      recordCount: result.scores.length,
      cardType: cardType,
    );
    return result;
  }

  /// The records an evidence engine may build connection claims from:
  /// top relevant only, and nothing at all when retrieval is weak-only —
  /// weak results never trigger major memory claims.
  static List<PressureCheckInRecord> connectionCandidates(
    List<PressureCheckInRecord> records, {
    DateTime? now,
    String? cardType,
  }) {
    final result = retrieve(records, now: now, cardType: cardType);
    if (!result.supportsConnectionClaims) return const [];
    return result.records;
  }

  static void _track(
    String event, {
    required ArchiveRetrievalBand band,
    required int recordCount,
    String? cardType,
  }) {
    final key = '$event|${cardType ?? ''}';
    if (!_trackedThisSession.add(key)) return;
    ActivationFunnelAnalytics.track(
      event,
      scoreBand: band.id,
      recordCount: recordCount,
      cardType: cardType,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  @visibleForTesting
  static void resetSessionForTest() {
    _notRelatedEntryIds.clear();
    _usefulEntryIds.clear();
    _notQuiteEntryIds.clear();
    _trackedThisSession.clear();
  }
}
