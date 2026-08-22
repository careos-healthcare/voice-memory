import 'package:archiveme_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:archiveme_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:archiveme_mobile/features/memory/archive_evidence_policy.dart';
import 'package:archiveme_mobile/features/memory/archive_evidence_type.dart';
import 'package:archiveme_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:archiveme_mobile/features/memory/archive_retrieval_score.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_preservation_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_frame.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_influence_level.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// A frame plus the claim-eligible records behind it. [candidates] is
/// empty whenever the influence level does not permit connection claims,
/// so no engine can use evidence its frame suppressed.
class MemoryAuthorityFraming {
  const MemoryAuthorityFraming({required this.frame, required this.candidates});

  final MemoryAuthorityFrame frame;
  final List<PressureCheckInRecord> candidates;

  bool get allowsConnectionClaims => frame.allowsConnectionClaims;
}

/// Builds the authority frame for one memory card — the explicit second
/// decision after retrieval. Retrieval finds relevant evidence; this
/// engine decides how much authority that evidence deserves, so memory
/// enters interpretation as structured evidence instead of vague text
/// that nearby context can dilute.
///
/// Order of authority — framing never overrides Memory Scope Controls:
/// 1. Scope off → blocked, nothing renders.
/// 2. Scope/retrieval suppression (fresh, unapproved, weak-only) →
///    suppress or background, no connection claims.
/// 3. Near-duplicate entries are grouped first so repetition is not
///    inflated.
/// 4. User confirmation is the only path to high authority — retrieval
///    relevance alone can not produce it.
class MemoryAuthorityFramingEngine {
  const MemoryAuthorityFramingEngine();

  /// A claim's newest supporting evidence older than this many days,
  /// while the archive itself kept moving, reads as superseded.
  static const int supersededGapDays = 8;

  /// Newest supporting evidence older than this is stale by itself.
  static const int staleAfterDays = 30;

  /// Distinct evidence groups needed to call the signal repeated.
  static const int repeatedGroupCount = 3;

  MemoryAuthorityFraming frame(
    List<PressureCheckInRecord> records, {
    required MemoryCardType cardType, DateTime? now,
  }) {
    final scope = MemoryScopePolicy.scope;
    if (scope == MemoryScope.off) {
      return _finish(
        cardType,
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.blocked,
        reasonId: MemoryAuthorityReason.memoryOff,
        candidates: const [],
      );
    }

    // "Treat future entries as new" rule from the inspect controls:
    // future similar entries do not auto-connect on this card.
    if (MemoryConnectionRules.isFutureFresh(cardType.id)) {
      return _finish(
        cardType,
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.freshEntry,
        candidates: const [],
      );
    }

    if (WrongThreadFeedback.isSessionSuppressed(cardType)) {
      return _finish(
        cardType,
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.freshEntry,
        candidates: const [],
      );
    }

    // Memory Scope Controls and retrieval scoring run first — framing
    // only ever narrows what they allow, never widens it.
    final result = ArchiveRetrievalPolicy.retrieve(
      records,
      now: now,
      cardType: cardType.id,
    );
    // Claims need at least one possible-band record behind them; the
    // weaker retrieved records may still support occurrence counting,
    // but they can not carry the claim on their own.
    final supporting = result.scores
        .where((s) => s.band == ArchiveRetrievalBand.possible)
        .map((s) => s.record)
        .toList();

    if (supporting.isEmpty) {
      final cause = _suppressionCause(
        scope,
        records,
        weakOnly: result.scores.isNotEmpty,
      );
      return _finish(
        cardType,
        state: cause.state,
        influence: cause.influence,
        reasonId: cause.reasonId,
        candidates: const [],
      );
    }

    final retrieved = result.records;
    var groups = _groupDuplicates(retrieved);

    final explicitThread = WrongThreadFeedback.explicitThreadFor(cardType);
    if (explicitThread != null) {
      groups = groups
          .where((r) => r.archiveThreadId == explicitThread)
          .toList();
    }
    groups = groups.where((r) {
      final threadId = r.archiveThreadId;
      if (threadId != null &&
          WrongThreadFeedback.isWrongPair(cardType, threadId)) {
        return false;
      }
      return true;
    }).toList();

    if (groups.isEmpty) {
      return _finish(
        cardType,
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.freshEntry,
        candidates: const [],
      );
    }

    final crossPackEvidence = ArchivePackScopePolicy.isCrossPack(groups);
    final crossPackAllowed = ArchivePackScopePolicy.allowsCrossPackByPolicy(
      groups,
    );
    final crossPackApproved = CrossPackConfirmation.isApproved(cardType.id);
    if (crossPackEvidence &&
        !crossPackAllowed &&
        !crossPackApproved &&
        !CrossPackConfirmation.isSessionSuppressed(cardType.id)) {
      // Keep pre-filter evidence so reliability can gate with confirmation
      // instead of silently dropping cross-pack records.
    } else {
      groups = ArchivePackScopePolicy.filterSamePackPreferred(
        groups,
        crossPackAllowed: crossPackAllowed || crossPackApproved,
      );
    }

    if (groups.isEmpty) {
      return _finish(
        cardType,
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.freshEntry,
        candidates: const [],
      );
    }
    final eligible = MemoryScopePolicy.connectionEligible(records);
    final anchor = now ?? _newest(eligible.isEmpty ? records : eligible);
    final newestSupporting = _newest(supporting);
    final newestEligible = _newest(eligible);

    final MemoryAuthorityState state;
    final MemoryInfluenceLevel influence;
    final String reasonId;
    if (groups.any((r) => r.connectionApproved) ||
        MemoryConnectionRules.isConfirmed(cardType.id)) {
      // The user explicitly confirmed the connection (per entry, or
      // "Keep connected" on the card) — the only path to high authority.
      state = MemoryAuthorityState.confirmed;
      influence = MemoryInfluenceLevel.highAuthority;
      reasonId = MemoryAuthorityReason.userConfirmed;
    } else if (groups.any(
      (r) => ArchiveRetrievalPolicy.isRecordNotQuite(r.entryId),
    )) {
      // Part of the evidence was rated "not quite" — it points in more
      // than one direction, so only cautious comparison is supported.
      state = MemoryAuthorityState.conflicting;
      influence = MemoryInfluenceLevel.compare;
      reasonId = MemoryAuthorityReason.mixedEvidence;
    } else if (newestEligible.difference(newestSupporting).inDays >=
        supersededGapDays) {
      // The archive kept moving after this evidence — do not present it
      // as current.
      state = MemoryAuthorityState.superseded;
      influence = MemoryInfluenceLevel.background;
      reasonId = MemoryAuthorityReason.changedLater;
    } else if (anchor.difference(newestSupporting).inDays > staleAfterDays) {
      state = MemoryAuthorityState.stale;
      influence = MemoryInfluenceLevel.background;
      reasonId = MemoryAuthorityReason.olderUnreinforced;
    } else if (retrieved.length >= 2 && groups.length == 1) {
      // Everything collapses into one near-identical group — repetition
      // was inflated, not real.
      state = MemoryAuthorityState.duplicate;
      influence = MemoryInfluenceLevel.background;
      reasonId = MemoryAuthorityReason.groupedDuplicate;
    } else if (groups.length >= repeatedGroupCount) {
      state = MemoryAuthorityState.repeated;
      influence = MemoryInfluenceLevel.compare;
      reasonId = MemoryAuthorityReason.repeatedSupported;
    } else {
      state = MemoryAuthorityState.current;
      influence = MemoryInfluenceLevel.compare;
      reasonId = MemoryAuthorityReason.recentSupported;
    }

    return _finish(
      cardType,
      state: state,
      influence: influence,
      reasonId: reasonId,
      candidates: influence.allowsConnectionClaims
          ? groups
          : const <PressureCheckInRecord>[],
      evidenceRecords: groups,
      now: now ?? anchor,
    );
  }

  /// Why nothing supports a claim: fresh entries, unapproved ask-mode
  /// entries, or weak-only retrieval.
  ({
    MemoryAuthorityState state,
    MemoryInfluenceLevel influence,
    String reasonId,
  })
  _suppressionCause(
    MemoryScope scope,
    List<PressureCheckInRecord> records, {
    required bool weakOnly,
  }) {
    if (weakOnly) {
      return (
        state: MemoryAuthorityState.stale,
        influence: MemoryInfluenceLevel.background,
        reasonId: MemoryAuthorityReason.olderUnreinforced,
      );
    }
    final nonFresh = records.where((r) => !r.treatAsNew).toList();
    if (records.isNotEmpty && nonFresh.isEmpty) {
      return (
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.freshEntry,
      );
    }
    if (scope == MemoryScope.ask &&
        nonFresh.any((r) => !r.connectionApproved)) {
      return (
        state: MemoryAuthorityState.fresh,
        influence: MemoryInfluenceLevel.suppress,
        reasonId: MemoryAuthorityReason.unapproved,
      );
    }
    return (
      state: MemoryAuthorityState.fresh,
      influence: MemoryInfluenceLevel.suppress,
      reasonId: MemoryAuthorityReason.freshEntry,
    );
  }

  MemoryAuthorityFraming _finish(
    MemoryCardType cardType, {
    required MemoryAuthorityState state,
    required MemoryInfluenceLevel influence,
    required String reasonId,
    required List<PressureCheckInRecord> candidates,
    DateTime? now,
    List<PressureCheckInRecord> evidenceRecords = const [],
  }) {
    final frame = MemoryAuthorityFrame(
      authorityState: state,
      influenceLevel: influence,
      reasonId: reasonId,
      cardType: cardType.id,
    );
    final inspectSource = evidenceRecords.isNotEmpty
        ? evidenceRecords
        : candidates;
    final claimCandidates = influence.allowsConnectionClaims
        ? candidates
        : const <PressureCheckInRecord>[];
    MemoryAuthorityFrameLog.record(
      frame,
      evidenceCount: inspectSource.length,
      evidence: _inspectItems(inspectSource, now ?? DateTime.now()),
      candidates: claimCandidates,
    );
    final described = ArchiveEvidencePolicy.describe(inspectSource);
    if (CuratedMemoryPreservationPolicy.summarySeparatedFromOriginal(
      described,
    )) {
      CuratedMemoryPreservationPolicy.noteSummarySeparated(
        source: 'memory_authority_framing',
        entryCount: inspectSource.length,
      );
    }
    return MemoryAuthorityFraming(frame: frame, candidates: claimCandidates);
  }

  /// Privacy-safe inspect items for "Show evidence": relative time
  /// bucket, evidence type, and confirmation only — no note text,
  /// snippets, dates, or entry ids.
  List<MemoryEvidenceInspectItem> _inspectItems(
    List<PressureCheckInRecord> candidates,
    DateTime now,
  ) {
    return ArchiveEvidencePolicy.describe(candidates)
        .map(
          (e) => MemoryEvidenceInspectItem(
            timeBucketLabel: e.timeBucketLabel(now),
            evidenceTypeLabel: e.type.label,
            userConfirmed: e.userConfirmed,
          ),
        )
        .toList();
  }

  /// Groups near-identical entries (same day, same option, same context
  /// tags, same note text) and keeps the newest of each group, so
  /// duplicates can not inflate authority or occurrence counts.
  ///
  /// "Keep exact details" records are never folded into a group: they
  /// stay individual exact evidence items, exactly as saved.
  List<PressureCheckInRecord> _groupDuplicates(
    List<PressureCheckInRecord> records,
  ) {
    final byKey = <String, PressureCheckInRecord>{};
    for (final record in records) {
      if (record.keepExactDetails || record.preserveOriginal) {
        byKey['preserved|${record.entryId}'] = record;
        continue;
      }
      final contexts = [...record.contextIds]..sort();
      final note = '${record.fear ?? ''} ${record.stopCostNote ?? ''}'
          .trim()
          .toLowerCase();
      final day =
          '${record.createdAt.year}-${record.createdAt.month}-'
          '${record.createdAt.day}';
      final key = '$day|${record.optionId}|${contexts.join(',')}|$note';
      final existing = byKey[key];
      if (existing == null || record.createdAt.isAfter(existing.createdAt)) {
        byKey[key] = record;
      }
    }
    final groups = byKey.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return groups;
  }

  DateTime _newest(List<PressureCheckInRecord> records) =>
      records.map((r) => r.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// One privacy-safe row in the "Show evidence" list. Holds display
/// labels and a confirmation flag only — by construction it can carry
/// no note text, snippet, date, or entry id.
@immutable
class MemoryEvidenceInspectItem {
  const MemoryEvidenceInspectItem({
    required this.timeBucketLabel,
    required this.evidenceTypeLabel,
    required this.userConfirmed,
  });

  final String timeBucketLabel;
  final String evidenceTypeLabel;
  final bool userConfirmed;
}

/// Session log of the latest frame per card type — how the cards and the
/// explanation sheet know which frame their evidence carried, without
/// widening any engine model. Frames hold stable ids only.
abstract class MemoryAuthorityFrameLog {
  MemoryAuthorityFrameLog._();

  static final Map<String, MemoryAuthorityFrame> _frames = {};
  static final Map<String, List<MemoryEvidenceInspectItem>> _evidence = {};
  static final Map<String, List<PressureCheckInRecord>> _candidates = {};
  static final Set<String> _trackedThisSession = <String>{};

  static void record(
    MemoryAuthorityFrame frame, {
    required int evidenceCount,
    List<MemoryEvidenceInspectItem> evidence = const [],
    List<PressureCheckInRecord> candidates = const [],
  }) {
    _frames[frame.cardType] = frame;
    _evidence[frame.cardType] = evidence;
    _candidates[frame.cardType] = candidates;
    _track(
      ActivationFunnelAnalytics.memoryAuthorityFrameCreated,
      frame,
      evidenceCount,
    );
    _track(
      frame.allowsConnectionClaims
          ? ActivationFunnelAnalytics.memoryInfluenceUsed
          : ActivationFunnelAnalytics.memoryInfluenceSuppressed,
      frame,
      evidenceCount,
    );
  }

  /// The latest frame computed for [cardType], if any. No memory card
  /// renders evidence without one.
  static MemoryAuthorityFrame? frameFor(MemoryCardType cardType) =>
      _frames[cardType.id];

  /// The privacy-safe evidence rows behind the latest frame for
  /// [cardType] — what "Show evidence" renders.
  static List<MemoryEvidenceInspectItem> evidenceFor(MemoryCardType cardType) =>
      _evidence[cardType.id] ?? const [];

  static List<PressureCheckInRecord> candidatesFor(MemoryCardType cardType) =>
      _candidates[cardType.id] ?? const [];

  static void _track(
    String event,
    MemoryAuthorityFrame frame,
    int evidenceCount,
  ) {
    final key =
        '$event|${frame.cardType}|${frame.influenceLevel.id}|'
        '${frame.reasonId}';
    if (!_trackedThisSession.add(key)) return;
    ActivationFunnelAnalytics.track(
      event,
      authorityState: frame.authorityState.id,
      influenceLevel: frame.influenceLevel.id,
      reasonId: frame.reasonId,
      cardType: frame.cardType,
      memoryScope: MemoryScopePolicy.scope.id,
      entryCount: evidenceCount,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _frames.clear();
    _evidence.clear();
    _candidates.clear();
    _trackedThisSession.clear();
  }
}