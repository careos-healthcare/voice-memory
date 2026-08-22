import 'package:archiveme_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard_copy.dart';

/// Copy guard — prevent ArchiveMe v1 from feeling like a life dashboard.
abstract final class NoDashboardPositioningGuard {
  NoDashboardPositioningGuard._();

  static const preferredProofTrailPhrases = [
    'proof trail',
    'one repeat',
    'first useful proof',
    'longer proof trail',
    'one sentence is enough',
    'what returned',
    'what changed',
    'what faded',
    'corrected',
    'returns',
    'changes',
    'fades',
  ];

  static const Map<String, NoDashboardPositioningGuardReason> blockedPositioningPhrases = {
    'command center': NoDashboardPositioningGuardReason.blockedCommandCenter,
    'life operating system':
        NoDashboardPositioningGuardReason.blockedLifeOperatingSystem,
    'second brain': NoDashboardPositioningGuardReason.blockedSecondBrain,
    'productivity system':
        NoDashboardPositioningGuardReason.blockedProductivitySystem,
    'personal analytics dashboard':
        NoDashboardPositioningGuardReason.blockedPersonalAnalyticsDashboard,
    'full life report': NoDashboardPositioningGuardReason.blockedFullLifeReport,
    'action plan manager':
        NoDashboardPositioningGuardReason.blockedActionPlanManager,
    'life dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'your dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'home dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'main dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'as a dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'as your dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'is a dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
    'is your dashboard':
        NoDashboardPositioningGuardReason.blockedDashboardPositioning,
  };

  static const warnedDashboardPhrases = [
    'dashboard overview',
    'dashboard view',
    'dashboard for your',
    'dashboard of your',
    'operating dashboard',
  ];

  static NoDashboardPositioningGuardResult evaluate(String copy) {
    final lower = copy.toLowerCase().trim();
    if (lower.isEmpty) {
      return const NoDashboardPositioningGuardResult(
        action: NoDashboardPositioningGuardAction.allowed,
        reason: NoDashboardPositioningGuardReason.allowedProofTrailLanguage,
      );
    }

    if (_isAntiDashboardInstruction(lower)) {
      return const NoDashboardPositioningGuardResult(
        action: NoDashboardPositioningGuardAction.allowed,
        reason: NoDashboardPositioningGuardReason.allowedProofTrailLanguage,
      );
    }

    for (final entry in blockedPositioningPhrases.entries) {
      if (lower.contains(entry.key) && !_isNegated(lower, entry.key)) {
        return NoDashboardPositioningGuardResult(
          action: NoDashboardPositioningGuardAction.block,
          reason: entry.value,
          matchedPhrase: entry.key,
        );
      }
    }

    for (final phrase in warnedDashboardPhrases) {
      if (lower.contains(phrase) && !_isNegated(lower, phrase)) {
        return NoDashboardPositioningGuardResult(
          action: NoDashboardPositioningGuardAction.warn,
          reason: NoDashboardPositioningGuardReason.warnedDashboardDrift,
          matchedPhrase: phrase,
        );
      }
    }

    if (lower.contains('dashboard') && !_isNegated(lower, 'dashboard')) {
      return const NoDashboardPositioningGuardResult(
        action: NoDashboardPositioningGuardAction.warn,
        reason: NoDashboardPositioningGuardReason.warnedDashboardDrift,
        matchedPhrase: 'dashboard',
      );
    }

    return const NoDashboardPositioningGuardResult(
      action: NoDashboardPositioningGuardAction.allowed,
      reason: NoDashboardPositioningGuardReason.allowedProofTrailLanguage,
    );
  }

  static bool passes(String copy) =>
      evaluate(copy).action != NoDashboardPositioningGuardAction.block;

  static bool passesStrict(String copy) =>
      evaluate(copy).action == NoDashboardPositioningGuardAction.allowed;

  static bool containsPreferredProofTrailLanguage(String copy) {
    final lower = copy.toLowerCase();
    for (final phrase in preferredProofTrailPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return lower.contains('proof trail');
  }

  static bool containsBlockedDashboardPositioning(String copy) =>
      evaluate(copy).action == NoDashboardPositioningGuardAction.block;

  static NoDashboardPositioningGuardSnapshot snapshot() =>
      const NoDashboardPositioningGuardSnapshot(
        headline: NoDashboardPositioningGuardCopy.headline,
        body: NoDashboardPositioningGuardCopy.body,
        preferredLanguageLine:
            NoDashboardPositioningGuardCopy.preferredLanguageLine,
        avoidLanguageLine: NoDashboardPositioningGuardCopy.avoidLanguageLine,
        blockLine: NoDashboardPositioningGuardCopy.blockLine,
        warnLine: NoDashboardPositioningGuardCopy.warnLine,
        guardrail: NoDashboardPositioningGuardCopy.guardrail,
      );

  static bool _isAntiDashboardInstruction(String lower) {
    const markers = [
      'more dashboards',
      'new dashboards',
      'no reports, dashboards',
      'blocked: new features, new dashboards',
      'secondary hidden: reports, dashboards',
      'risky drift: new surfaces, dashboards',
      'do not make dashboards',
      'ranking dashboard',
      'dashboard to maintain',
      'or dashboard to maintain',
      'not a map, dashboard',
      'avoid dashboard, command center',
      'avoid mind-map maintenance, dashboard',
      'ai, storage, dashboards, rankings',
      'system, dashboard, ranking tool',
      'tracker, chat app, storage app, or dashboard to maintain',
      'storage app, second brain, or dashboard to maintain',
      'the value is meaningful resurfacing — not more notes, more dashboards',
      'therapist dashboard',
      'risky: full timeline',
      'avoid dashboard, command center, life operating system',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) return true;
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
    if (RegExp(r'not a [^,.]+(?:, [^,.]+)*,?\s*$').hasMatch(before)) {
      return true;
    }
    return false;
  }
}

enum NoDashboardPositioningGuardAction { allowed, block, warn }

enum NoDashboardPositioningGuardReason {
  allowedProofTrailLanguage,
  blockedDashboardPositioning,
  blockedCommandCenter,
  blockedLifeOperatingSystem,
  blockedSecondBrain,
  blockedProductivitySystem,
  blockedPersonalAnalyticsDashboard,
  blockedFullLifeReport,
  blockedActionPlanManager,
  warnedDashboardDrift,
}

class NoDashboardPositioningGuardResult {
  const NoDashboardPositioningGuardResult({
    required this.action,
    required this.reason,
    this.matchedPhrase,
  });

  final NoDashboardPositioningGuardAction action;
  final NoDashboardPositioningGuardReason reason;
  final String? matchedPhrase;
}

class NoDashboardPositioningGuardSnapshot {
  const NoDashboardPositioningGuardSnapshot({
    required this.headline,
    required this.body,
    required this.preferredLanguageLine,
    required this.avoidLanguageLine,
    required this.blockLine,
    required this.warnLine,
    required this.guardrail,
  });

  final String headline;
  final String body;
  final String preferredLanguageLine;
  final String avoidLanguageLine;
  final String blockLine;
  final String warnLine;
  final String guardrail;
}