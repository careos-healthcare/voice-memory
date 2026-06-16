import '../product/consumer_ui_copy.dart';

/// Consumer onboarding copy and structured page data.
abstract class OnboardingPages {
  OnboardingPages._();

  static const int pageCount = 4;

  static const List<OnboardingPageData> pages = [
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingPositioningHeadline,
      body: ConsumerUiCopy.onboardingPositioningBody,
      visual: OnboardingVisualKind.patternNetwork,
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingStep1Title,
      body: ConsumerUiCopy.onboardingStep1Body,
      visual: OnboardingVisualKind.stepBadge,
      stepNumber: 1,
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingStep2Title,
      body: ConsumerUiCopy.onboardingStep2Body,
      visual: OnboardingVisualKind.stepBadge,
      stepNumber: 2,
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingStep3Title,
      body: ConsumerUiCopy.onboardingStep3Body,
      visual: OnboardingVisualKind.stepBadge,
      stepNumber: 3,
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
