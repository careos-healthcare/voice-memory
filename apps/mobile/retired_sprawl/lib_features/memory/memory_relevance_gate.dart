import 'package:archiveme_mobile/features/memory/memory_relevance_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:flutter/foundation.dart';

/// Decides how much the archive is allowed to say about the present.
///
/// Fixes the core trust complaint that memory can over-constrain the user
/// by forcing new entries into old patterns. Memory should be evidence,
/// not gravity:
///
/// - `fresh`: no evidence to connect — no archive-based interpretation.
/// - `weak`: only one loose signal — no major memory cards.
/// - `possible`: two or more safe signals, but not enough to claim a
///   return — cautious wording only.
/// - `strong`: only when the existing thread-return evidence engine
///   already supports the connection. The gate never upgrades anything
///   on its own.
///
/// The user stays in control: a connection can be marked "Not related"
/// (suppressing that specific connection for the session), and an entry
/// can be treated as new or saved without connecting. Nothing is deleted
/// and raw entries are never altered; memory is never globally disabled.
///
/// Pure and deterministic; no AI calls, no content leaves the device.
class MemoryRelevanceGate {
  const MemoryRelevanceGate();

  static const _threadEngine = ThreadReturnEvidenceEngine();

  /// Stable connection id for the insights-screen archive connection.
  static const String insightsConnectionId = 'memory_relevance';

  /// Records within this window of each other count as a density signal
  /// (3+ recent entries suggest something active that may relate).
  static const int densityWindowDays = 14;
  static const int densityMinRecords = 3;

  /// Words too short or too generic to count as a repeated-language signal.
  static const int _minWordLength = 3;
  static const Set<String> _ignoredWords = {
    'the',
    'and',
    'for',
    'that',
    'this',
    'with',
    'was',
    'were',
    'will',
    'would',
    'not',
    'but',
    'had',
    'have',
    'has',
    'about',
    'from',
    'they',
    'them',
    'when',
    'then',
    'than',
    'what',
    'how',
    'why',
    'who',
    'all',
    'too',
    'very',
    'just',
    'like',
    'into',
    'out',
    'off',
    'might',
    'maybe',
    'could',
    'because',
    'being',
    'been',
    'still',
    'even',
    'more',
    'again',
  };

  /// Builds the relevance read for the archive as it stands.
  ///
  /// `strong` is delegated entirely to the existing evidence engines —
  /// the gate never claims strength they have not already established.
  MemoryRelevanceAssessment assess(
    List<PressureCheckInRecord> allRecords, {
    DateTime? now,
  }) {
    // Central memory policy: fresh entries and the user's memory scope
    // are fully inert for memory — they never raise relevance, not even
    // to a cautious "possible".
    final records = MemoryScopePolicy.connectionEligible(allRecords);
    final entryCount = records.length;
    if (entryCount < 2) {
      return MemoryRelevanceAssessment(
        relevance: MemoryRelevance.fresh,
        signalCount: 0,
        entryCount: entryCount,
      );
    }

    // Strong is strictly engine-backed thread-return evidence — the gate
    // never upgrades density or loose overlap into a claimed return.
    final engineSupported = _threadEngine.build(records, now: now).hasEvidence;
    final signals = _signalCount(records, now: now);

    final MemoryRelevance relevance;
    if (engineSupported) {
      relevance = MemoryRelevance.strong;
    } else if (signals >= 2) {
      relevance = MemoryRelevance.possible;
    } else if (signals == 1) {
      relevance = MemoryRelevance.weak;
    } else {
      relevance = MemoryRelevance.fresh;
    }

    return MemoryRelevanceAssessment(
      relevance: relevance,
      signalCount: signals,
      entryCount: entryCount,
    );
  }

  /// Loose connection signals, counted once per dimension:
  /// a repeated context id, a repeated option id, a repeated meaningful
  /// free-text word, or 3+ records inside the recent density window.
  int _signalCount(List<PressureCheckInRecord> records, {DateTime? now}) {
    var signals = 0;
    if (_hasRepeated(records, (r) => r.contextIds)) signals++;
    if (_hasRepeated(records, (r) => [r.optionId])) signals++;
    if (_hasRepeatedWord(records)) signals++;
    if (_hasRecentDensity(records, now ?? DateTime.now())) signals++;
    return signals;
  }

  bool _hasRepeated(
    List<PressureCheckInRecord> records,
    Iterable<String> Function(PressureCheckInRecord) keysOf,
  ) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final key in keysOf(record).toSet()) {
        final normalized = key.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        final next = (counts[normalized] ?? 0) + 1;
        if (next >= 2) return true;
        counts[normalized] = next;
      }
    }
    return false;
  }

  bool _hasRepeatedWord(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      final text = '${record.fear ?? ''} ${record.stopCostNote ?? ''}';
      final words = <String>{};
      for (final raw in text.toLowerCase().split(RegExp("[^a-z']+"))) {
        final word = raw.trim();
        if (word.length < _minWordLength) continue;
        if (_ignoredWords.contains(word)) continue;
        words.add(word);
      }
      for (final word in words) {
        final next = (counts[word] ?? 0) + 1;
        if (next >= 2) return true;
        counts[word] = next;
      }
    }
    return false;
  }

  bool _hasRecentDensity(List<PressureCheckInRecord> records, DateTime now) {
    final cutoff = now.subtract(const Duration(days: densityWindowDays));
    var recent = 0;
    for (final record in records) {
      if (record.createdAt.isAfter(cutoff)) recent++;
      if (recent >= densityMinRecords) return true;
    }
    return false;
  }

  // --- Session-scoped user control (never persisted, never global) ---

  /// Connections the user marked "Not related" this session. Suppresses
  /// only that specific connection; archive content is never deleted and
  /// raw entries are never altered.
  static final Set<String> _notRelatedThisSession = <String>{};

  /// The user asked for the current entry to be treated as new.
  static bool treatAsNewThisSession = false;

  /// The user saved without connecting — memory interpretation is
  /// bypassed for this session.
  static bool saveWithoutConnectingThisSession = false;

  static void markNotRelated(String connectionId) {
    _notRelatedThisSession.add(connectionId);
  }

  static bool isNotRelated(String connectionId) =>
      _notRelatedThisSession.contains(connectionId);

  /// True when the user opted out of connecting this session.
  static bool get bypassThisSession =>
      treatAsNewThisSession || saveWithoutConnectingThisSession;

  /// Whether major memory cards (thread return, guided plan, belief
  /// distance, weekly review) may render. Strong, engine-backed evidence
  /// is required, and the user's session choices always win.
  static bool allowMemoryCards(MemoryRelevanceAssessment assessment) {
    if (bypassThisSession) return false;
    if (isNotRelated(insightsConnectionId)) return false;
    return assessment.relevance == MemoryRelevance.strong;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    _notRelatedThisSession.clear();
    treatAsNewThisSession = false;
    saveWithoutConnectingThisSession = false;
  }
}