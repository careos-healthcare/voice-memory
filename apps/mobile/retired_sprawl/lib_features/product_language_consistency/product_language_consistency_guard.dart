import 'package:archiveme_mobile/features/first_five_minutes/first_five_minutes_simplification_copy.dart';
import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_onboarding_copy.dart';
import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:archiveme_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:archiveme_mobile/features/product_language_consistency/product_language_consistency_guard_copy.dart';

/// Guard — proof-trail language wins over dashboard/story/storage language.
abstract final class ProductLanguageConsistencyGuard {
  ProductLanguageConsistencyGuard._();

  static const preferredProofTrailPhrases = [
    'repeat',
    'proof',
    'proof trail',
    'longer proof trail',
    'returns',
    'changes',
    'fades',
    'corrected',
    'one sentence',
    'compares later',
  ];

  static const Map<String, ProductLanguageConsistencyReason> blockedRiskyPhrases = {
    'full timeline': ProductLanguageConsistencyReason.blockedFullTimeline,
    'longer story': ProductLanguageConsistencyReason.blockedLongerStory,
    'life operating system':
        ProductLanguageConsistencyReason.blockedLifeOperatingSystem,
    'second brain': ProductLanguageConsistencyReason.blockedSecondBrain,
    'archive health score':
        ProductLanguageConsistencyReason.blockedArchiveHealthScore,
    'memory quality score':
        ProductLanguageConsistencyReason.blockedMemoryQualityScore,
    'extra storage': ProductLanguageConsistencyReason.blockedStorage,
    'unlimited storage': ProductLanguageConsistencyReason.blockedStorage,
    'storage app': ProductLanguageConsistencyReason.blockedStorage,
    'unlock reports':
        ProductLanguageConsistencyReason.blockedReportPrimaryValue,
    'reports are what pro':
        ProductLanguageConsistencyReason.blockedReportPrimaryValue,
    'main benefit: reports':
        ProductLanguageConsistencyReason.blockedReportPrimaryValue,
  };

  static const Map<String, ProductLanguageConsistencyReason> warnedRiskyPhrases = {
    'full pattern timeline':
        ProductLanguageConsistencyReason.warnedFullTimeline,
    'full memory': ProductLanguageConsistencyReason.warnedStorage,
    'private monthly report':
        ProductLanguageConsistencyReason.warnedReportPrimaryValue,
    'monthly private report':
        ProductLanguageConsistencyReason.warnedReportPrimaryValue,
    'your dashboard': ProductLanguageConsistencyReason.warnedDashboard,
    'analytics dashboard': ProductLanguageConsistencyReason.warnedDashboard,
    'dashboard to maintain': ProductLanguageConsistencyReason.warnedDashboard,
  };

  static ProductLanguageConsistencyResult evaluate(String copy) {
    final lower = copy.toLowerCase().trim();
    if (lower.isEmpty) {
      return const ProductLanguageConsistencyResult(
        action: ProductLanguageConsistencyAction.preferredAligned,
        reason: ProductLanguageConsistencyReason.preferredProofTrailLanguage,
      );
    }

    if (_isAntiRiskInstruction(lower)) {
      return const ProductLanguageConsistencyResult(
        action: ProductLanguageConsistencyAction.preferredAligned,
        reason: ProductLanguageConsistencyReason.preferredProofTrailLanguage,
      );
    }

    for (final entry in blockedRiskyPhrases.entries) {
      if (lower.contains(entry.key) && !_isNegated(lower, entry.key)) {
        return ProductLanguageConsistencyResult(
          action: ProductLanguageConsistencyAction.highRiskBlocked,
          reason: entry.value,
          matchedPhrase: entry.key,
        );
      }
    }

    if (lower.contains('dashboard') && !_isNegated(lower, 'dashboard')) {
      return const ProductLanguageConsistencyResult(
        action: ProductLanguageConsistencyAction.highRiskBlocked,
        reason: ProductLanguageConsistencyReason.blockedDashboard,
        matchedPhrase: 'dashboard',
      );
    }

    for (final entry in warnedRiskyPhrases.entries) {
      if (lower.contains(entry.key) && !_isNegated(lower, entry.key)) {
        return ProductLanguageConsistencyResult(
          action: ProductLanguageConsistencyAction.riskyLanguageWarn,
          reason: entry.value,
          matchedPhrase: entry.key,
        );
      }
    }

    if (containsPreferredProofTrailLanguage(copy)) {
      return const ProductLanguageConsistencyResult(
        action: ProductLanguageConsistencyAction.preferredAligned,
        reason: ProductLanguageConsistencyReason.preferredProofTrailLanguage,
      );
    }

    return const ProductLanguageConsistencyResult(
      action: ProductLanguageConsistencyAction.preferredAligned,
      reason: ProductLanguageConsistencyReason.neutralCopy,
    );
  }

  static bool passesFirstJourney(String copy) =>
      evaluate(copy).action != ProductLanguageConsistencyAction.highRiskBlocked;

  static bool passesProPromise(String copy) {
    final result = evaluate(copy);
    return result.action != ProductLanguageConsistencyAction.highRiskBlocked &&
        result.action != ProductLanguageConsistencyAction.riskyLanguageWarn;
  }

  static bool containsPreferredProofTrailLanguage(String copy) {
    final lower = copy.toLowerCase();
    for (final phrase in preferredProofTrailPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  static List<String> firstJourneyCopyBlocks() => [
    ...FirstFiveMinutesSimplificationCopy.allVisibleStrings(),
    ...LandingAppContinuityCopy.allVisibleStrings(),
    FirstSessionOnboardingCopy.title,
    FirstSessionOnboardingCopy.body,
    FirstSessionOnboardingCopy.step1Title,
    FirstSessionOnboardingCopy.step1Body,
    FirstSessionOnboardingCopy.step2Title,
    FirstSessionOnboardingCopy.step2Body,
    FirstSessionOnboardingCopy.step3Title,
    FirstSessionOnboardingCopy.step3Body,
    FirstSessionOnboardingCopy.startCta,
    FirstSessionOnboardingCopy.exploreCta,
    FirstSessionOnboardingCopy.notChatFootnote,
  ];

  static List<String> proPromiseCopyBlocks() => [
    ...ProSinglePromiseCopy.allVisibleStrings(),
    ...PaywallAlignmentCopy.allPaywallStrings(),
  ];

  static ProductLanguageConsistencySnapshot snapshot() =>
      const ProductLanguageConsistencySnapshot(
        headline: ProductLanguageConsistencyGuardCopy.headline,
        body: ProductLanguageConsistencyGuardCopy.body,
        preferredLanguageLine:
            ProductLanguageConsistencyGuardCopy.preferredLanguageLine,
        riskyLanguageLine:
            ProductLanguageConsistencyGuardCopy.riskyLanguageLine,
        blockLine: ProductLanguageConsistencyGuardCopy.blockLine,
        warnLine: ProductLanguageConsistencyGuardCopy.warnLine,
        guardrail: ProductLanguageConsistencyGuardCopy.guardrail,
      );

  static bool _isAntiRiskInstruction(String lower) {
    const markers = [
      'risky: full timeline',
      'not extra storage',
      'not more chat',
      'not a dashboard',
      'no reports, dashboards',
      'hide reports, action items, archive health',
      'storage app, second brain, or dashboard to maintain',
      'ai, storage, dashboards, rankings, reports',
      'do not change all copy blindly',
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

enum ProductLanguageConsistencyAction {
  preferredAligned,
  riskyLanguageWarn,
  highRiskBlocked,
}

enum ProductLanguageConsistencyReason {
  preferredProofTrailLanguage,
  neutralCopy,
  blockedFullTimeline,
  blockedLongerStory,
  blockedDashboard,
  blockedArchiveHealthScore,
  blockedMemoryQualityScore,
  blockedReportPrimaryValue,
  blockedStorage,
  blockedSecondBrain,
  blockedLifeOperatingSystem,
  warnedFullTimeline,
  warnedDashboard,
  warnedReportPrimaryValue,
  warnedStorage,
}

class ProductLanguageConsistencyResult {
  const ProductLanguageConsistencyResult({
    required this.action,
    required this.reason,
    this.matchedPhrase,
  });

  final ProductLanguageConsistencyAction action;
  final ProductLanguageConsistencyReason reason;
  final String? matchedPhrase;
}

class ProductLanguageConsistencySnapshot {
  const ProductLanguageConsistencySnapshot({
    required this.headline,
    required this.body,
    required this.preferredLanguageLine,
    required this.riskyLanguageLine,
    required this.blockLine,
    required this.warnLine,
    required this.guardrail,
  });

  final String headline;
  final String body;
  final String preferredLanguageLine;
  final String riskyLanguageLine;
  final String blockLine;
  final String warnLine;
  final String guardrail;
}