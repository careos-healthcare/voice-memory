import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';

/// Consumer onboarding copy and structured page data.
abstract class OnboardingPages {
  OnboardingPages._();

  /// Welcome screen only. Evidence, consent, and the confirmation hero
  /// are separate steps driven by OnboardingScreen, each with one job.
  static const int pageCount = 1;

  static const List<OnboardingPageData> pages = [
    OnboardingPageData(
      title: OnboardingV1Copy.welcomeTitle,
      body: OnboardingV1Copy.welcomeBody,
      visual: OnboardingVisualKind.patternNetwork,
    ),
  ];
}

enum OnboardingVisualKind {
  patternNetwork,
  evidenceChips,
  confidenceGrowth,
  beliefShift,
  insightPreview,
  checkPreview,
  stepBadge,
}

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.body,
    required this.visual,
    this.evidenceExamples = const [],
    this.confidenceSteps = const [40, 65, 85],
    this.oldBelief,
    this.newBelief,
    this.insightBullets = const [],
    this.stepNumber,
  });

  final String title;
  final String body;
  final OnboardingVisualKind visual;
  final List<String> evidenceExamples;
  final List<int> confidenceSteps;
  final String? oldBelief;
  final String? newBelief;
  final List<String> insightBullets;
  final int? stepNumber;
}
