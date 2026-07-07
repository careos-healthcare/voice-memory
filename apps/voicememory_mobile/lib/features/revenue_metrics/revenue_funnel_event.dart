/// Stable revenue-funnel event ids — metadata only, never user content.
enum RevenueFunnelEvent {
  firstProofSeen('first_proof_seen'),
  proLockSeen('pro_lock_seen'),
  proLockCtaTapped('pro_lock_cta_tapped'),
  monthlyReportPreviewSeen('monthly_report_preview_seen'),
  monthlyReportPreviewCtaTapped('monthly_report_preview_cta_tapped'),
  backupBridgeSeen('backup_bridge_seen'),
  backupBridgeCtaTapped('backup_bridge_cta_tapped'),
  proEvidenceValueSeen('pro_evidence_value_seen'),
  proEvidenceValueCtaTapped('pro_evidence_value_cta_tapped'),
  paywallSeen('paywall_seen'),
  paywallPurchaseCtaTapped('paywall_purchase_cta_tapped'),
  paywallRestoreTapped('paywall_restore_tapped'),
  paywallDismissed('paywall_dismissed');

  const RevenueFunnelEvent(this.id);

  final String id;

  bool get isValueEvent => switch (this) {
        RevenueFunnelEvent.firstProofSeen ||
        RevenueFunnelEvent.proLockSeen ||
        RevenueFunnelEvent.monthlyReportPreviewSeen ||
        RevenueFunnelEvent.backupBridgeSeen ||
        RevenueFunnelEvent.proEvidenceValueSeen ||
        RevenueFunnelEvent.paywallSeen =>
          true,
        _ => false,
      };

  bool get isCtaEvent => switch (this) {
        RevenueFunnelEvent.proLockCtaTapped ||
        RevenueFunnelEvent.monthlyReportPreviewCtaTapped ||
        RevenueFunnelEvent.backupBridgeCtaTapped ||
        RevenueFunnelEvent.proEvidenceValueCtaTapped ||
        RevenueFunnelEvent.paywallPurchaseCtaTapped ||
        RevenueFunnelEvent.paywallRestoreTapped =>
          true,
        _ => false,
      };

  bool get isDismissEvent => this == RevenueFunnelEvent.paywallDismissed;
}
