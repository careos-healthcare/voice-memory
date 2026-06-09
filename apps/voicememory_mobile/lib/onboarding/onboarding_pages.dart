import '../product/consumer_ui_copy.dart';

/// Consumer onboarding copy and structured page data.
abstract final class OnboardingPages {
  OnboardingPages._();

  static const int pageCount = 4;

  static const List<OnboardingPageData> pages = [
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingPositioningHeadline,
      body: ConsumerUiCopy.onboardingPositioningBody,
      visual: OnboardingVisualKind.patternNetwork,
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingPage2Title,
      body: ConsumerUiCopy.onboardingPage2Body,
      visual: OnboardingVisualKind.insightPreview,
      insightBullets: [
        'What you kept doing',
        'What stopping felt like it would cost',
        'What felt not enough afterward',
      ],
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingPage3Title,
      body: ConsumerUiCopy.onboardingPage3Body,
      visual: OnboardingVisualKind.evidenceChips,
      evidenceExamples: [
        'Proving loop started',
        'Moment 1 saved',
        'Moment 2 tests the read',
      ],
    ),
    OnboardingPageData(
      title: ConsumerUiCopy.onboardingPage4Title,
      body: ConsumerUiCopy.onboardingPage4Body,
      visual: OnboardingVisualKind.checkPreview,
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
  });

  final String title;
  final String body;
  final OnboardingVisualKind visual;
  final List<String> evidenceExamples;
  final List<int> confidenceSteps;
  final String? oldBelief;
  final String? newBelief;
  final List<String> insightBullets;
}
