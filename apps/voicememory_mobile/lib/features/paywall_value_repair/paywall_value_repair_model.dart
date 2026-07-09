class PaywallValueRepairResult {
  const PaywallValueRepairResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.bullets,
    required this.supportLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.source,
    required this.entryCount,
  });

  static const hidden = PaywallValueRepairResult(
    shouldShow: false,
    title: '',
    body: '',
    bullets: [],
    supportLine: '',
    primaryCta: '',
    secondaryCta: '',
    source: '',
    entryCount: 0,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final List<String> bullets;
  final String supportLine;
  final String primaryCta;
  final String secondaryCta;
  final String source;
  final int entryCount;
}
