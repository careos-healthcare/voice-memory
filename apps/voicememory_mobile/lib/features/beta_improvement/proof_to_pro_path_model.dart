/// Paired proof-clarity → Pro-packaging path — proof first, Pro second.
class ProofToProPathModel {
  const ProofToProPathModel({
    required this.showProofEmotionalClarity,
    required this.showProPackagingBridge,
    required this.showProPackagingPaywallCopy,
    required this.suppressStandaloneProBridgeCard,
    required this.reason,
  });

  final bool showProofEmotionalClarity;
  final bool showProPackagingBridge;
  final bool showProPackagingPaywallCopy;
  final bool suppressStandaloneProBridgeCard;
  final String reason;

  static const hidden = ProofToProPathModel(
    showProofEmotionalClarity: false,
    showProPackagingBridge: false,
    showProPackagingPaywallCopy: false,
    suppressStandaloneProBridgeCard: false,
    reason: 'Proof-to-Pro path hidden',
  );

  ProofToProPathModel copyWith({
    bool? showProofEmotionalClarity,
    bool? showProPackagingBridge,
    bool? showProPackagingPaywallCopy,
    bool? suppressStandaloneProBridgeCard,
    String? reason,
  }) =>
      ProofToProPathModel(
        showProofEmotionalClarity:
            showProofEmotionalClarity ?? this.showProofEmotionalClarity,
        showProPackagingBridge:
            showProPackagingBridge ?? this.showProPackagingBridge,
        showProPackagingPaywallCopy:
            showProPackagingPaywallCopy ?? this.showProPackagingPaywallCopy,
        suppressStandaloneProBridgeCard: suppressStandaloneProBridgeCard ??
            this.suppressStandaloneProBridgeCard,
        reason: reason ?? this.reason,
      );
}
