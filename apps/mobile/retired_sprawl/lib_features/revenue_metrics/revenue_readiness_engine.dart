import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_event.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_snapshot.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_readiness_model.dart';

/// Builds a developer-only revenue readiness dashboard from local funnel events.
abstract final class RevenueReadinessEngine {
  RevenueReadinessEngine._();

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static RevenueReadinessDashboard build() {
    final events = RevenueFunnelAnalytics.recordedEvents;
    final snapshot = RevenueFunnelSnapshot.fromEvents(events);
    final eventTypes = events.map((record) => record.event).toSet();

    final hasFirstProof = eventTypes.contains(
      RevenueFunnelEvent.firstProofSeen,
    );
    final hasProInterest = _hasProInterest(eventTypes);
    final hasPaywallSeen = eventTypes.contains(RevenueFunnelEvent.paywallSeen);
    final hasPurchaseIntent = eventTypes.contains(
      RevenueFunnelEvent.paywallPurchaseCtaTapped,
    );
    final hasDismissed = eventTypes.contains(
      RevenueFunnelEvent.paywallDismissed,
    );
    final hasRestore = eventTypes.contains(
      RevenueFunnelEvent.paywallRestoreTapped,
    );

    return RevenueReadinessDashboard(
      title: RevenueReadinessCopy.title,
      subtitle: RevenueReadinessCopy.subtitle,
      rows: [
        RevenueReadinessRow(
          id: RevenueReadinessRowId.proofSeen,
          label: RevenueReadinessCopy.proofSeen,
          status: _status(
            present: hasFirstProof,
            strong: hasFirstProof && hasProInterest,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.proInterest,
          label: RevenueReadinessCopy.proInterest,
          status: _status(
            present: hasProInterest,
            strong: hasProInterest && hasPaywallSeen,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.paywallReached,
          label: RevenueReadinessCopy.paywallReached,
          status: _status(
            present: hasPaywallSeen,
            strong: hasPaywallSeen && hasPurchaseIntent,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.purchaseIntent,
          label: RevenueReadinessCopy.purchaseIntent,
          status: _status(
            present: hasPurchaseIntent,
            strong: hasPurchaseIntent,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.dismissed,
          label: RevenueReadinessCopy.dismissed,
          status: _status(
            present: hasDismissed,
            strong: hasDismissed && hasPaywallSeen,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.restoreChecked,
          label: RevenueReadinessCopy.restoreChecked,
          status: _status(
            present: hasRestore,
            strong: hasRestore && hasPaywallSeen,
          ),
        ),
        RevenueReadinessRow(
          id: RevenueReadinessRowId.noContentCaptured,
          label: RevenueReadinessCopy.noContentCaptured,
          status: snapshot.noContentCaptured
              ? RevenueReadinessStatus.strong
              : RevenueReadinessStatus.missing,
        ),
      ],
      surfaces: _surfaces(eventTypes),
      noPersonalContentCaptured: snapshot.noContentCaptured,
    );
  }

  static bool _hasProInterest(Set<RevenueFunnelEvent> eventTypes) =>
      eventTypes.contains(RevenueFunnelEvent.proLockCtaTapped) ||
      eventTypes.contains(RevenueFunnelEvent.monthlyReportPreviewCtaTapped) ||
      eventTypes.contains(RevenueFunnelEvent.backupBridgeCtaTapped) ||
      eventTypes.contains(RevenueFunnelEvent.proEvidenceValueCtaTapped);

  static List<RevenueReadinessSurface> _surfaces(
    Set<RevenueFunnelEvent> eventTypes,
  ) => [
    RevenueReadinessSurface(
      id: 'pro_lock',
      label: RevenueReadinessCopy.surfaceProLock,
      seen:
          eventTypes.contains(RevenueFunnelEvent.proLockSeen) ||
          eventTypes.contains(RevenueFunnelEvent.proLockCtaTapped),
    ),
    RevenueReadinessSurface(
      id: 'monthly_report_preview',
      label: RevenueReadinessCopy.surfaceMonthlyReportPreview,
      seen:
          eventTypes.contains(RevenueFunnelEvent.monthlyReportPreviewSeen) ||
          eventTypes.contains(RevenueFunnelEvent.monthlyReportPreviewCtaTapped),
    ),
    RevenueReadinessSurface(
      id: 'backup_bridge',
      label: RevenueReadinessCopy.surfaceBackupBridge,
      seen:
          eventTypes.contains(RevenueFunnelEvent.backupBridgeSeen) ||
          eventTypes.contains(RevenueFunnelEvent.backupBridgeCtaTapped),
    ),
    RevenueReadinessSurface(
      id: 'pro_evidence_value',
      label: RevenueReadinessCopy.surfaceProEvidenceValue,
      seen:
          eventTypes.contains(RevenueFunnelEvent.proEvidenceValueSeen) ||
          eventTypes.contains(RevenueFunnelEvent.proEvidenceValueCtaTapped),
    ),
  ];

  static RevenueReadinessStatus _status({
    required bool present,
    required bool strong,
  }) {
    if (!present) return RevenueReadinessStatus.missing;
    if (strong) return RevenueReadinessStatus.strong;
    return RevenueReadinessStatus.seen;
  }
}