import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'proof_specificity_boost_copy.dart';

enum ProofSpecificityBoostSurface {
  timelineProofMoment,
  firstProofPayoff,
  patterns,
}

extension ProofSpecificityBoostSurfaceStorage on ProofSpecificityBoostSurface {
  String get storageValue => switch (this) {
        ProofSpecificityBoostSurface.timelineProofMoment =>
          'timeline_proof_moment',
        ProofSpecificityBoostSurface.firstProofPayoff => 'first_proof_payoff',
        ProofSpecificityBoostSurface.patterns => 'patterns',
      };

  String get analyticsValue => storageValue;
}

/// Resolved boost card — safe display labels only, no journal text.
class ProofSpecificityBoostResult {
  const ProofSpecificityBoostResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasBeliefSurface,
    required this.evidenceAnchors,
    required this.usesFallbackEvidenceLine,
    required this.hasSafeAnchor,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasBeliefSurface;
  final List<String> evidenceAnchors;
  final bool usesFallbackEvidenceLine;
  final bool hasSafeAnchor;

  factory ProofSpecificityBoostResult.hidden({
    required String source,
    int entryCount = 0,
  }) =>
      ProofSpecificityBoostResult(
        shouldShow: false,
        entryCount: entryCount,
        source: source,
        hasConfirmedRepeat: false,
        hasBeliefSurface: false,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        hasSafeAnchor: false,
      );
}

class ProofSpecificityBoostRecord {
  const ProofSpecificityBoostRecord({
    this.answerType,
    this.surface,
    this.entryCount,
    this.answeredAt,
  });

  static const empty = ProofSpecificityBoostRecord();

  final ProofSpecificityBoostAnswerType? answerType;
  final ProofSpecificityBoostSurface? surface;
  final int? entryCount;
  final DateTime? answeredAt;

  bool get answered => answerType != null;

  Map<String, dynamic> toJson() => {
        if (answerType != null) 'answerType': answerType!.storageValue,
        if (surface != null) 'surface': surface!.storageValue,
        if (entryCount != null) 'entryCount': entryCount,
        if (answeredAt != null)
          'answeredAt': answeredAt!.toUtc().toIso8601String(),
      };

  factory ProofSpecificityBoostRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return ProofSpecificityBoostRecord(
      answerType: _answerFromRaw(json['answerType'] as String?),
      surface: _surfaceFromRaw(json['surface'] as String?),
      entryCount:
          json['entryCount'] is int ? json['entryCount'] as int : null,
      answeredAt: _timestampFromRaw(json['answeredAt'] as String?),
    );
  }

  static ProofSpecificityBoostAnswerType? _answerFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return ProofSpecificityBoostAnswerType.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => ProofSpecificityBoostAnswerType.yes,
    );
  }

  static ProofSpecificityBoostSurface? _surfaceFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return ProofSpecificityBoostSurface.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => ProofSpecificityBoostSurface.timelineProofMoment,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Local-only specificity feedback per proof surface.
class ProofSpecificityBoostStore {
  ProofSpecificityBoostStore(this._prefs);

  static const prefsKey = 'proofSpecificityBoost_v1';

  final MobilePrefsStore _prefs;

  static final Map<ProofSpecificityBoostSurface, ProofSpecificityBoostRecord>
      _cached = {};
  static bool _loaded = false;

  static ProofSpecificityBoostRecord recordFor(
    ProofSpecificityBoostSurface surface,
  ) =>
      _cached[surface] ?? ProofSpecificityBoostRecord.empty;

  static bool isAnswered(ProofSpecificityBoostSurface surface) =>
      recordFor(surface).answered;

  static ProofSpecificityBoostStore instance() =>
      ProofSpecificityBoostStore(AppServices.instance.prefs);

  static ProofSpecificityBoostStore forPrefs(MobilePrefsStore prefs) =>
      ProofSpecificityBoostStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    final raw = await store._prefs.readMap(prefsKey);
    _hydrateFromRaw(raw);
    _loaded = true;
  }

  static void _hydrateFromRaw(Map<String, dynamic>? raw) {
    _cached.clear();
    if (raw == null || raw.isEmpty) return;
    final answers = raw['answers'];
    if (answers is! Map) return;
    for (final surface in ProofSpecificityBoostSurface.values) {
      final entry = answers[surface.storageValue];
      if (entry is Map<String, dynamic>) {
        _cached[surface] = ProofSpecificityBoostRecord.fromJson(entry);
      } else if (entry is Map) {
        _cached[surface] = ProofSpecificityBoostRecord.fromJson(
          Map<String, dynamic>.from(entry),
        );
      }
    }
  }

  Future<void> saveAnswer({
    required ProofSpecificityBoostSurface surface,
    required ProofSpecificityBoostAnswerType answerType,
    required int entryCount,
  }) async {
    final record = ProofSpecificityBoostRecord(
      answerType: answerType,
      surface: surface,
      entryCount: entryCount,
      answeredAt: DateTime.now().toUtc(),
    );
    _cached[surface] = record;
    _loaded = true;
    final answers = <String, dynamic>{
      for (final item in ProofSpecificityBoostSurface.values)
        item.storageValue: (_cached[item] ?? ProofSpecificityBoostRecord.empty)
            .toJson(),
    };
    await _prefs.writeMap(prefsKey, {'answers': answers});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached.clear();
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}
