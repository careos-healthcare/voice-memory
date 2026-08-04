import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../beta_activation/beta_activation_summary_tracker.dart';
import 'first_proof_truth_model.dart';

/// Local answers for first proof truth — keyed by proof entry ids, never text.
class FirstProofTruthStore {
  FirstProofTruthStore(this._prefs);

  static const answeredPrefsKey = 'firstProofTruthAnswered_v1';

  final MobilePrefsStore _prefs;

  static final Map<String, FirstProofTruthAnswer> _answered = {};
  static bool _loaded = false;

  static FirstProofTruthStore instance() =>
      FirstProofTruthStore(AppServices.instance.prefs);

  static FirstProofTruthStore forPrefs(MobilePrefsStore prefs) =>
      FirstProofTruthStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    _answered
      ..clear()
      ..addAll(await store._loadAnswered());
    _loaded = true;
  }

  static bool hasAnswered(String proofKey) =>
      proofKey.isNotEmpty && _answered.containsKey(proofKey);

  static FirstProofTruthAnswer? answerFor(String proofKey) =>
      _answered[proofKey];

  /// Stable id from the three eligible entries — never pattern or transcript text.
  static String proofKeyForFirstProof(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return '';
    final ids = eligible.take(3).map((e) => e.id).toList()..sort();
    return ids.join('|');
  }

  Future<Map<String, FirstProofTruthAnswer>> _loadAnswered() async {
    final raw = await _prefs.readMap(answeredPrefsKey);
    final answeredRaw = raw?['answered'];
    if (answeredRaw is! Map) return {};

    final out = <String, FirstProofTruthAnswer>{};
    for (final entry in answeredRaw.entries) {
      final key = entry.key?.toString() ?? '';
      if (key.isEmpty) continue;
      final answer = _parseAnswer(entry.value);
      if (answer != null) out[key] = answer;
    }
    return out;
  }

  static FirstProofTruthAnswer? _parseAnswer(Object? raw) => switch (raw) {
    'yes' => FirstProofTruthAnswer.yes,
    'sort_of' => FirstProofTruthAnswer.sortOf,
    'no' => FirstProofTruthAnswer.no,
    _ => null,
  };

  static String _answerKey(FirstProofTruthAnswer answer) => switch (answer) {
    FirstProofTruthAnswer.yes => 'yes',
    FirstProofTruthAnswer.sortOf => 'sort_of',
    FirstProofTruthAnswer.no => 'no',
  };

  Future<void> saveAnswer({
    required String proofKey,
    required FirstProofTruthAnswer answer,
  }) async {
    if (proofKey.isEmpty) return;
    _answered[proofKey] = answer;
    _loaded = true;

    await _prefs.updateMap(answeredPrefsKey, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final answered = Map<String, dynamic>.from(
        map['answered'] is Map ? map['answered'] as Map : {},
      );
      answered[proofKey] = _answerKey(answer);
      map['answered'] = answered;
      map['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      return map;
    });

    await BetaActivationSummaryTracker.trackFirstProofTruthAnswer(answer);
  }

  static void invalidateCache() {
    _answered.clear();
    _loaded = false;
  }

  static Future<void> clearForRestore(MobilePrefsStore? prefs) async {
    invalidateCache();
    if (prefs == null) return;
    await prefs.writeMap(answeredPrefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) =>
      clearForRestore(prefs);
}
