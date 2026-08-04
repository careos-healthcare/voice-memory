import '../product/auditable_change_positioning.dart';
import '../product/core_product_vision.dart';

/// Consumer onboarding copy and structured page data.
abstract class OnboardingPages {
  OnboardingPages._();

  static const int pageCount = 1;
  static const primaryAction = 'Record a moment';
  static const secondaryAction = 'Type instead';

  static const List<OnboardingPageData> pages = [
    OnboardingPageData(
      title: AuditableChangePositioning.primaryPromise,
      body: CoreProductVision.valueProposition,
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
