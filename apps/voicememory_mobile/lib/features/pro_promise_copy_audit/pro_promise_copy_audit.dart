import 'pro_promise_copy_audit_copy.dart';

/// Pro promise copy audit — find copy that conflicts with the single trail promise.
abstract final class ProPromiseCopyAudit {
  ProPromiseCopyAudit._();

  static const preferredPhrases = [
    'longer proof trail',
    'evidence trail',
    'first useful proof',
    'what returns',
    'what changed',
    'what fades',
    'gets corrected',
    'keeps the trail',
    'keeps tracking whether',
  ];

  static const blockedFullTimelinePhrases = [
    'full timeline',
    'full archive over time',
    'longer timeline',
    'complete timeline',
  ];

  static const blockedLongerStoryPhrases = [
    'longer story',
    'full story',
    'your whole story',
  ];

  static const blockedMoreAiPhrases = [
    'more ai',
    'more chat',
    'smarter ai',
    'ai insights',
    'ai companion',
    'unlimited ai',
  ];

  static const blockedMoreFeaturesPhrases = [
    'more features',
    'unlock more features',
    'feature list',
    'all features',
  ];

  static const blockedReportsPrimaryPhrases = [
    'unlock reports',
    'unlocks reports',
    'reports are included',
    'reports are what pro',
    'main benefit: reports',
    'private reports are the main',
    'pro gives you reports',
  ];

  static const blockedDashboardPrimaryPhrases = [
    'analytics dashboard',
    'your dashboard',
    'dashboard to track',
    'pro dashboard',
  ];

  static const blockedStorageBackupPhrases = [
    'cloud backup',
    'extra storage',
    'unlimited storage',
    'backup your archive',
    'secure backup',
  ];

  static const blockedRankingScoringPhrases = [
    'importance scoring',
    'ranked patterns',
    'pattern ranking',
    'rank what matters',
    'priority scoring',
  ];

  static ProPromiseCopyAuditResult audit(String copy) {
    final lower = copy.toLowerCase();
    final conflict = _firstConflict(lower);
    if (conflict != null) {
      return ProPromiseCopyAuditResult(
        copy: copy,
        decision: ProPromiseCopyAuditDecision.conflictFound,
        conflict: conflict,
        message: _messageFor(conflict),
        neutralizeHint: _neutralizeHintFor(conflict),
      );
    }

    if (containsPreferredLanguage(copy)) {
      return ProPromiseCopyAuditResult(
        copy: copy,
        decision: ProPromiseCopyAuditDecision.aligned,
        message: ProPromiseCopyAuditCopy.alignedLine,
      );
    }

    if (_mentionsProPromise(lower)) {
      return ProPromiseCopyAuditResult(
        copy: copy,
        decision: ProPromiseCopyAuditDecision.needsReview,
        message: ProPromiseCopyAuditCopy.reviewLine,
      );
    }

    return ProPromiseCopyAuditResult(
      copy: copy,
      decision: ProPromiseCopyAuditDecision.aligned,
      message: ProPromiseCopyAuditCopy.alignedLine,
    );
  }

  static ProPromiseCopyAuditBatchResult auditAll(
    Iterable<ProPromiseCopyAuditEntry> entries,
  ) {
    final results = [for (final entry in entries) audit(entry.copy)];
    final conflicts = results
        .where(
          (result) =>
              result.decision == ProPromiseCopyAuditDecision.conflictFound,
        )
        .toList();
    return ProPromiseCopyAuditBatchResult(
      results: results,
      conflictCount: conflicts.length,
      allAligned: conflicts.isEmpty,
    );
  }

  static ProPromiseCopyAuditReport report({
    ProPromiseCopyAuditBatchResult? batch,
  }) => ProPromiseCopyAuditReport(
    headline: ProPromiseCopyAuditCopy.headline,
    body: ProPromiseCopyAuditCopy.body,
    preferredFreeLine: ProPromiseCopyAuditCopy.preferredFreeLine,
    preferredProLine: ProPromiseCopyAuditCopy.preferredProLine,
    preferredContinuityLine: ProPromiseCopyAuditCopy.preferredContinuityLine,
    guardrail: ProPromiseCopyAuditCopy.guardrail,
    batch: batch,
  );

  static bool containsPreferredLanguage(String copy) {
    final lower = copy.toLowerCase();
    for (final phrase in preferredPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return lower.contains('proof trail') || lower.contains('evidence trail');
  }

  static bool hasConflictingPromise(String copy) =>
      audit(copy).decision == ProPromiseCopyAuditDecision.conflictFound;

  static ProPromiseCopyConflict? _firstConflict(String lower) {
    if (_matchesAnyUnlessNegated(lower, blockedFullTimelinePhrases)) {
      return ProPromiseCopyConflict.fullTimelinePromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedLongerStoryPhrases)) {
      return ProPromiseCopyConflict.longerStoryPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedMoreAiPhrases)) {
      return ProPromiseCopyConflict.moreAiPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedMoreFeaturesPhrases)) {
      return ProPromiseCopyConflict.moreFeaturesPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedReportsPrimaryPhrases)) {
      return ProPromiseCopyConflict.reportsPrimaryPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedDashboardPrimaryPhrases)) {
      return ProPromiseCopyConflict.dashboardPrimaryPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedStorageBackupPhrases)) {
      return ProPromiseCopyConflict.storageBackupPromise;
    }
    if (_matchesAnyUnlessNegated(lower, blockedRankingScoringPhrases)) {
      return ProPromiseCopyConflict.rankingScoringPromise;
    }
    if (_containsReportsPrimaryPromise(lower)) {
      return ProPromiseCopyConflict.reportsPrimaryPromise;
    }
    return null;
  }

  static bool _containsReportsPrimaryPromise(String lower) {
    if (!lower.contains('report')) return false;
    if (_isNegated(lower, 'report')) return false;
    if (lower.contains('proof trail') || lower.contains('evidence trail')) {
      return false;
    }
    return lower.contains('pro keeps') &&
        lower.contains('report') &&
        !lower.contains('trail');
  }

  static bool _mentionsProPromise(String lower) =>
      lower.contains('pro keeps') ||
      lower.contains('pro unlocks') ||
      lower.contains('with pro') ||
      lower.contains('upgrade to pro');

  static bool _matchesAnyUnlessNegated(String lower, List<String> phrases) {
    for (final phrase in phrases) {
      if (lower.contains(phrase) && !_isNegated(lower, phrase)) {
        return true;
      }
    }
    return false;
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

  static String _messageFor(ProPromiseCopyConflict conflict) =>
      switch (conflict) {
        ProPromiseCopyConflict.fullTimelinePromise =>
          ProPromiseCopyAuditCopy.conflictFullTimelineLine,
        ProPromiseCopyConflict.longerStoryPromise =>
          ProPromiseCopyAuditCopy.conflictLongerStoryLine,
        ProPromiseCopyConflict.moreAiPromise =>
          ProPromiseCopyAuditCopy.conflictMoreAiLine,
        ProPromiseCopyConflict.moreFeaturesPromise =>
          ProPromiseCopyAuditCopy.conflictMoreFeaturesLine,
        ProPromiseCopyConflict.reportsPrimaryPromise =>
          ProPromiseCopyAuditCopy.conflictReportsLine,
        ProPromiseCopyConflict.dashboardPrimaryPromise =>
          ProPromiseCopyAuditCopy.conflictDashboardLine,
        ProPromiseCopyConflict.storageBackupPromise =>
          ProPromiseCopyAuditCopy.conflictStorageLine,
        ProPromiseCopyConflict.rankingScoringPromise =>
          ProPromiseCopyAuditCopy.conflictRankingLine,
      };

  static String _neutralizeHintFor(ProPromiseCopyConflict conflict) =>
      switch (conflict) {
        ProPromiseCopyConflict.fullTimelinePromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.longerStoryPromise =>
          ProPromiseCopyAuditCopy.preferredContinuityLine,
        ProPromiseCopyConflict.moreAiPromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.moreFeaturesPromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.reportsPrimaryPromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.dashboardPrimaryPromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.storageBackupPromise =>
          ProPromiseCopyAuditCopy.preferredProLine,
        ProPromiseCopyConflict.rankingScoringPromise =>
          ProPromiseCopyAuditCopy.preferredContinuityLine,
      };
}

enum ProPromiseCopyAuditDecision { aligned, conflictFound, needsReview }

enum ProPromiseCopyConflict {
  fullTimelinePromise,
  longerStoryPromise,
  moreAiPromise,
  moreFeaturesPromise,
  reportsPrimaryPromise,
  dashboardPrimaryPromise,
  storageBackupPromise,
  rankingScoringPromise,
}

class ProPromiseCopyAuditEntry {
  const ProPromiseCopyAuditEntry({required this.id, required this.copy});

  final String id;
  final String copy;
}

class ProPromiseCopyAuditResult {
  const ProPromiseCopyAuditResult({
    required this.copy,
    required this.decision,
    required this.message,
    this.conflict,
    this.neutralizeHint,
  });

  final String copy;
  final ProPromiseCopyAuditDecision decision;
  final ProPromiseCopyConflict? conflict;
  final String message;
  final String? neutralizeHint;

  bool get isAligned => decision == ProPromiseCopyAuditDecision.aligned;
}

class ProPromiseCopyAuditBatchResult {
  const ProPromiseCopyAuditBatchResult({
    required this.results,
    required this.conflictCount,
    required this.allAligned,
  });

  final List<ProPromiseCopyAuditResult> results;
  final int conflictCount;
  final bool allAligned;
}

class ProPromiseCopyAuditReport {
  const ProPromiseCopyAuditReport({
    required this.headline,
    required this.body,
    required this.preferredFreeLine,
    required this.preferredProLine,
    required this.preferredContinuityLine,
    required this.guardrail,
    this.batch,
  });

  final String headline;
  final String body;
  final String preferredFreeLine;
  final String preferredProLine;
  final String preferredContinuityLine;
  final String guardrail;
  final ProPromiseCopyAuditBatchResult? batch;
}
