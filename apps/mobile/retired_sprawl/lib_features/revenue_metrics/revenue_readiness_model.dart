/// Developer-only revenue readiness row status.
enum RevenueReadinessStatus {
  missing('missing'),
  seen('seen'),
  strong('strong');

  const RevenueReadinessStatus(this.label);

  final String label;
}

enum RevenueReadinessRowId {
  proofSeen,
  proInterest,
  paywallReached,
  purchaseIntent,
  dismissed,
  restoreChecked,
  noContentCaptured,
}

class RevenueReadinessRow {
  const RevenueReadinessRow({
    required this.id,
    required this.label,
    required this.status,
  });

  final RevenueReadinessRowId id;
  final String label;
  final RevenueReadinessStatus status;
}

class RevenueReadinessSurface {
  const RevenueReadinessSurface({
    required this.id,
    required this.label,
    required this.seen,
  });

  final String id;
  final String label;
  final bool seen;
}

class RevenueReadinessDashboard {
  const RevenueReadinessDashboard({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.surfaces,
    required this.noPersonalContentCaptured,
  });

  final String title;
  final String subtitle;
  final List<RevenueReadinessRow> rows;
  final List<RevenueReadinessSurface> surfaces;
  final bool noPersonalContentCaptured;

  Iterable<String> get allDisplayedText => [
    title,
    subtitle,
    ...rows.map((row) => row.label),
    ...rows.map((row) => row.status.label),
    ...surfaces.map((surface) => surface.label),
    if (noPersonalContentCaptured) 'No content captured',
  ];
}

abstract final class RevenueReadinessCopy {
  RevenueReadinessCopy._();

  static const title = 'Revenue readiness';
  static const subtitle = 'Checks whether proof is reaching the paywall.';

  static const proofSeen = 'Proof seen';
  static const proInterest = 'Pro interest';
  static const paywallReached = 'Paywall reached';
  static const purchaseIntent = 'Purchase intent';
  static const dismissed = 'Dismissed';
  static const restoreChecked = 'Restore checked';
  static const noContentCaptured = 'No content captured';

  static const surfacesTitle = 'Surfaces seen';

  static const surfaceProLock = 'Pro lock';
  static const surfaceMonthlyReportPreview = 'Monthly report preview';
  static const surfaceBackupBridge = 'Backup bridge';
  static const surfaceProEvidenceValue = 'Pro evidence value';
}