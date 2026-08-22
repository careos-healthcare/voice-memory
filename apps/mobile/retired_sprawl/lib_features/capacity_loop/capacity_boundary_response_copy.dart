import 'package:archiveme_mobile/features/capacity_loop/capacity_boundary_response_models.dart';

/// Copy for capacity boundary response — fixed templates only.
abstract final class CapacityBoundaryResponseCopy {
  CapacityBoundaryResponseCopy._();

  static const route = '/capacity-boundary-response';
  static const archiveHomeRoute = '/archive-belief';
  static const capacityLoopRoute = '/capacity-loop';
  static const weeklyReviewRoute = '/capacity-weekly-review';

  static const title = 'Your default yes pause';
  static const subtitle = 'Pick one line to use before agreeing too quickly.';
  static const body = 'This gives you space before saying yes.';

  static const chooseResponseCta = 'Choose response';
  static const useNextTimeCta = 'Use this next time';
  static const copyResponseCta = 'Copy response';

  static const cardEyebrow = 'Default yes pause';
  static const weeklyReviewSectionTitle = 'Choose your default yes pause';
  static const loopSectionTitle = 'Your default yes pause';

  static const templates = <CapacityBoundaryResponseTemplate>[
    CapacityBoundaryResponseTemplate(
      id: CapacityBoundaryResponseIds.checkCapacityComeBack,
      text: 'Let me check my capacity and come back to you.',
    ),
    CapacityBoundaryResponseTemplate(
      id: CapacityBoundaryResponseIds.checkCommitmentsFirst,
      text: 'I need to look at what I already committed to first.',
    ),
    CapacityBoundaryResponseTemplate(
      id: CapacityBoundaryResponseIds.cannotAnswerNow,
      text: 'I cannot answer properly right now — I will come back to you.',
    ),
    CapacityBoundaryResponseTemplate(
      id: CapacityBoundaryResponseIds.wantToHelpCheck,
      text: 'I want to help, but I need to check what I can realistically do.',
    ),
    CapacityBoundaryResponseTemplate(
      id: CapacityBoundaryResponseIds.needPauseBeforeYes,
      text: 'I need to pause before I say yes.',
    ),
  ];

  static String? textForId(String? responseId) {
    if (responseId == null || responseId.isEmpty) return null;
    for (final template in templates) {
      if (template.id == responseId) return template.text;
    }
    return null;
  }

  static String recordDefaultPauseLabel(String responseText) =>
      'Default pause: $responseText';

  static List<String> allVisibleStrings() => [
    title,
    subtitle,
    body,
    chooseResponseCta,
    useNextTimeCta,
    copyResponseCta,
    cardEyebrow,
    weeklyReviewSectionTitle,
    loopSectionTitle,
    ...templates.map((template) => template.text),
  ];
}