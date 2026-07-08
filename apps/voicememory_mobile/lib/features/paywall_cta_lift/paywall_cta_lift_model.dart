class PaywallCtaLiftResult {
  const PaywallCtaLiftResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.supportLine,
    required this.source,
    required this.proofConnected,
  });

  static const hidden = PaywallCtaLiftResult(
    shouldShow: false,
    title: '',
    body: '',
    supportLine: '',
    source: '',
    proofConnected: false,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String supportLine;
  final String source;
  final bool proofConnected;
}
