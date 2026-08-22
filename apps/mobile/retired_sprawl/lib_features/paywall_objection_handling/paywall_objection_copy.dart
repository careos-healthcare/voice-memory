import 'package:archiveme_mobile/features/paywall_objection_handling/paywall_objection_model.dart';

/// Paywall objection Q&A — short answers, no scarcity or testimonials.
abstract final class PaywallObjectionCopy {
  PaywallObjectionCopy._();

  static const sectionTitle = 'Common questions';

  static const notJournalingQuestion = 'Is this just journaling?';
  static const notJournalingAnswer =
      'No. You save moments when they stand out. ArchiveMe tracks what returns, '
      'changes, fades, and becomes useful.';

  static const notAiChatQuestion = 'Is this just more AI chat?';
  static const notAiChatAnswer =
      'No. The value is the evidence trail, not another conversation.';

  static const whatProKeepsQuestion = 'What does Pro keep?';
  static const whatProKeepsAnswer =
      'The full pattern timeline, correction history, current vs fading signals, '
      'monthly private report, and backup continuity.';

  static const stayInControlQuestion = 'Can I stay in control?';
  static const stayInControlAnswer =
      'Yes. You can delete entries and correct the timeline.';

  static const restorePurchasesQuestion = 'Can I restore purchases?';
  static const restorePurchasesAnswer =
      'Yes. Restore purchases is always available on the paywall.';

  static const bannedFakeClaims = <String>[
    'limited time',
    'only today',
    'testimonial',
    'users say',
    '5-star',
    'offer ends',
  ];

  static const bannedMedicalTerms = <String>[
    'therapy',
    'diagnosis',
    'treatment',
    'clinical',
    'medical report',
  ];

  static List<PaywallObjectionRow> allRows() => const [
    PaywallObjectionRow(
      id: PaywallObjectionId.notJournaling,
      question: notJournalingQuestion,
      answer: notJournalingAnswer,
    ),
    PaywallObjectionRow(
      id: PaywallObjectionId.notAiChat,
      question: notAiChatQuestion,
      answer: notAiChatAnswer,
    ),
    PaywallObjectionRow(
      id: PaywallObjectionId.whatProKeeps,
      question: whatProKeepsQuestion,
      answer: whatProKeepsAnswer,
    ),
    PaywallObjectionRow(
      id: PaywallObjectionId.stayInControl,
      question: stayInControlQuestion,
      answer: stayInControlAnswer,
    ),
    PaywallObjectionRow(
      id: PaywallObjectionId.restorePurchases,
      question: restorePurchasesQuestion,
      answer: restorePurchasesAnswer,
    ),
  ];

  static List<String> allDisplayedStrings() => [
    sectionTitle,
    for (final row in allRows()) ...[row.question, row.answer],
  ];
}