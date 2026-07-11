import 'trail_language_guard_copy.dart';

/// Trail language guard — block maintenance-heavy copy, prefer proof-trail terms.
abstract final class TrailLanguageGuard {
  TrailLanguageGuard._();

  static const preferredTrailPhrases = [
    'proof trail',
    'evidence trail',
    'saved moments',
    'what came back',
    'what returned',
    'changed',
    'faded',
    'corrected',
    'one sentence is enough',
    'archiveme compares it later',
  ];

  static const blockedMindMapPhrases = [
    'maintain your mind map',
    'keep your mind map active',
    'update your map daily',
    'mind-map maintenance',
  ];

  static const blockedDashboardPhrases = [
    'dashboard to maintain',
  ];

  static const blockedDailyTrackerPhrases = [
    'daily tracker',
  ];

  static const blockedStreakPhrases = [
    'keep your streak',
    'daily streak',
    'streak counter',
  ];

  static const blockedStoragePhrases = [
    'storage app',
    'second brain',
  ];

  static const blockedRankingPhrases = [
    'ranked patterns',
  ];

  static const blockedTherapyPhrases = [
    'therapy',
    'diagnosis',
    'coach',
  ];

  static const blockedChatPhrases = [
    'voice chat',
    'chat box',
    'ai companion',
  ];

  static TrailLanguageGuardResult isAllowedCopy(String copy) {
    final lower = copy.toLowerCase();

    final blocked = _firstBlockedReason(lower);
    if (blocked != null) {
      return TrailLanguageGuardResult.blocked(reason: blocked);
    }

    return const TrailLanguageGuardResult(
      isAllowed: true,
      reason: TrailLanguageGuardReason.allowedProofTrailLanguage,
    );
  }

  static bool containsPreferredTrailLanguage(String copy) {
    final lower = copy.toLowerCase();
    for (final phrase in preferredTrailPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return lower.contains('trail') && !lower.contains('mind-map maintenance');
  }

  static bool containsBlockedMaintenanceLanguage(String copy) {
    final lower = copy.toLowerCase();
    return _matchesAny(lower, blockedMindMapPhrases) ||
        _matchesAny(lower, blockedDashboardPhrases) ||
        _matchesAny(lower, blockedDailyTrackerPhrases) ||
        _matchesAny(lower, blockedStreakPhrases) ||
        _matchesAny(lower, blockedStoragePhrases) ||
        _matchesAny(lower, blockedRankingPhrases) ||
        _matchesAny(lower, blockedTherapyPhrases) ||
        _matchesAny(lower, blockedChatPhrases) ||
        _containsStreakLanguage(lower);
  }

  static TrailLanguageGuardReason? _firstBlockedReason(String lower) {
    if (_matchesAnyUnlessNegated(lower, blockedMindMapPhrases)) {
      return TrailLanguageGuardReason.blockedMindMapMaintenance;
    }
    if (_matchesAnyUnlessNegated(lower, blockedDashboardPhrases)) {
      return TrailLanguageGuardReason.blockedDashboardMaintenance;
    }
    if (_matchesAnyUnlessNegated(lower, blockedDailyTrackerPhrases)) {
      return TrailLanguageGuardReason.blockedDailyTracker;
    }
    if (_containsStreakLanguageUnlessNegated(lower)) {
      return TrailLanguageGuardReason.blockedStreakLanguage;
    }
    if (_matchesAnyUnlessNegated(lower, blockedStoragePhrases)) {
      return TrailLanguageGuardReason.blockedStoragePositioning;
    }
    if (_matchesAnyUnlessNegated(lower, blockedChatPhrases)) {
      return TrailLanguageGuardReason.blockedChatPositioning;
    }
    if (_matchesAnyUnlessNegated(lower, blockedRankingPhrases)) {
      return TrailLanguageGuardReason.blockedRankingPositioning;
    }
    if (_matchesAnyUnlessNegated(lower, blockedTherapyPhrases)) {
      return TrailLanguageGuardReason.blockedTherapyLanguage;
    }
    return null;
  }

  static bool _matchesAny(String lower, List<String> phrases) {
    for (final phrase in phrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  static bool _matchesAnyUnlessNegated(String lower, List<String> phrases) {
    for (final phrase in phrases) {
      if (lower.contains(phrase) && !_isNegated(lower, phrase)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsStreakLanguage(String lower) =>
      lower.contains('streak') &&
      !lower.contains('no streak') &&
      !lower.contains('avoid') &&
      !lower.contains('streaks,');

  static bool _containsStreakLanguageUnlessNegated(String lower) {
    if (!lower.contains('streak')) return false;
    if (_matchesAnyUnlessNegated(lower, blockedStreakPhrases)) return true;
    return _containsStreakLanguage(lower);
  }

  static bool _isNegated(String lower, String phrase) {
    final index = lower.indexOf(phrase);
    if (index < 0) return false;
    final before = lower.substring(0, index);
    if (before.contains('avoid')) return true;
    if (before.contains('do not')) return true;
    if (RegExp(r'\bnot\b').hasMatch(before)) return true;
    if (RegExp(r'\bno\b').hasMatch(before)) return true;
    return false;
  }

  static TrailLanguageGuardSnapshot snapshot() =>
      const TrailLanguageGuardSnapshot(
        headline: TrailLanguageGuardCopy.headline,
        body: TrailLanguageGuardCopy.body,
        preferredLanguageLine: TrailLanguageGuardCopy.preferredLanguageLine,
        avoidLanguageLine: TrailLanguageGuardCopy.avoidLanguageLine,
        whyTrailLine: TrailLanguageGuardCopy.whyTrailLine,
        proLine: TrailLanguageGuardCopy.proLine,
        guardrail: TrailLanguageGuardCopy.guardrail,
      );
}

enum TrailLanguageGuardReason {
  allowedProofTrailLanguage,
  blockedMindMapMaintenance,
  blockedDashboardMaintenance,
  blockedDailyTracker,
  blockedStreakLanguage,
  blockedStoragePositioning,
  blockedChatPositioning,
  blockedRankingPositioning,
  blockedTherapyLanguage,
}

class TrailLanguageGuardResult {
  const TrailLanguageGuardResult({
    required this.isAllowed,
    required this.reason,
  });

  factory TrailLanguageGuardResult.blocked({
    required TrailLanguageGuardReason reason,
  }) =>
      TrailLanguageGuardResult(isAllowed: false, reason: reason);

  final bool isAllowed;
  final TrailLanguageGuardReason reason;
}

class TrailLanguageGuardSnapshot {
  const TrailLanguageGuardSnapshot({
    required this.headline,
    required this.body,
    required this.preferredLanguageLine,
    required this.avoidLanguageLine,
    required this.whyTrailLine,
    required this.proLine,
    required this.guardrail,
  });

  final String headline;
  final String body;
  final String preferredLanguageLine;
  final String avoidLanguageLine;
  final String whyTrailLine;
  final String proLine;
  final String guardrail;
}
