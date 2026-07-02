import 'archive_journey_copy.dart';

class ArchiveJourneyStep {
  const ArchiveJourneyStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

enum ArchiveJourneyExplainerVariant {
  compact,
  full,
}

class ArchiveJourneyExplainer {
  const ArchiveJourneyExplainer({
    required this.title,
    required this.steps,
    required this.variant,
  });

  final String title;
  final List<ArchiveJourneyStep> steps;
  final ArchiveJourneyExplainerVariant variant;

  static const step1 = ArchiveJourneyStep(
    title: ArchiveJourneyCopy.step1Title,
    body: ArchiveJourneyCopy.step1Body,
  );

  static const step2 = ArchiveJourneyStep(
    title: ArchiveJourneyCopy.step2Title,
    body: ArchiveJourneyCopy.step2Body,
  );

  static const step3 = ArchiveJourneyStep(
    title: ArchiveJourneyCopy.step3Title,
    body: ArchiveJourneyCopy.step3Body,
  );

  static const step4 = ArchiveJourneyStep(
    title: ArchiveJourneyCopy.step4Title,
    body: ArchiveJourneyCopy.step4Body,
  );

  static const step5 = ArchiveJourneyStep(
    title: ArchiveJourneyCopy.step5Title,
    body: ArchiveJourneyCopy.step5Body,
  );

  static ArchiveJourneyExplainer compact() => const ArchiveJourneyExplainer(
        title: ArchiveJourneyCopy.title,
        steps: [step1, step2, step3],
        variant: ArchiveJourneyExplainerVariant.compact,
      );

  static ArchiveJourneyExplainer full() => const ArchiveJourneyExplainer(
        title: ArchiveJourneyCopy.title,
        steps: [step1, step2, step3, step4, step5],
        variant: ArchiveJourneyExplainerVariant.full,
      );

  List<String> get visibleCopyBlocks => [
        title,
        for (final step in steps) ...[step.title, step.body],
      ];
}
