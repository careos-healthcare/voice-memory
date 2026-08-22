enum PaywallObjectionId {
  notJournaling,
  notAiChat,
  whatProKeeps,
  stayInControl,
  restorePurchases,
}

extension PaywallObjectionIdAnalytics on PaywallObjectionId {
  String get analyticsValue => switch (this) {
    PaywallObjectionId.notJournaling => 'not_journaling',
    PaywallObjectionId.notAiChat => 'not_ai_chat',
    PaywallObjectionId.whatProKeeps => 'what_pro_keeps',
    PaywallObjectionId.stayInControl => 'stay_in_control',
    PaywallObjectionId.restorePurchases => 'restore_purchases',
  };
}

class PaywallObjectionRow {
  const PaywallObjectionRow({
    required this.id,
    required this.question,
    required this.answer,
  });

  final PaywallObjectionId id;
  final String question;
  final String answer;
}

class PaywallObjectionSectionResult {
  const PaywallObjectionSectionResult({
    required this.shouldShow,
    required this.source,
    required this.surface,
    required this.rows,
    required this.title,
  });

  final bool shouldShow;
  final String source;
  final String surface;
  final List<PaywallObjectionRow> rows;
  final String title;
}