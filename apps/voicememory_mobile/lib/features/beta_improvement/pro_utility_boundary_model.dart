/// Gated Pro utility rows for history, export, and private report preview.
class ProUtilityBoundaryModel {
  const ProUtilityBoundaryModel({
    required this.showHistory,
    required this.showExport,
    required this.showPrivateReportPreview,
    required this.isPreviewOnly,
    required this.shouldShowProBridge,
    required this.reason,
    required this.exportLinkLive,
    required this.privateReportLive,
  });

  final bool showHistory;
  final bool showExport;
  final bool showPrivateReportPreview;
  final bool isPreviewOnly;
  final bool shouldShowProBridge;
  final String reason;
  final bool exportLinkLive;
  final bool privateReportLive;

  bool get shouldShowSection =>
      showHistory || showExport || showPrivateReportPreview;

  ProUtilityBoundaryModel copyWith({
    bool? showHistory,
    bool? showExport,
    bool? showPrivateReportPreview,
    bool? isPreviewOnly,
    bool? shouldShowProBridge,
    String? reason,
    bool? exportLinkLive,
    bool? privateReportLive,
  }) =>
      ProUtilityBoundaryModel(
        showHistory: showHistory ?? this.showHistory,
        showExport: showExport ?? this.showExport,
        showPrivateReportPreview:
            showPrivateReportPreview ?? this.showPrivateReportPreview,
        isPreviewOnly: isPreviewOnly ?? this.isPreviewOnly,
        shouldShowProBridge: shouldShowProBridge ?? this.shouldShowProBridge,
        reason: reason ?? this.reason,
        exportLinkLive: exportLinkLive ?? this.exportLinkLive,
        privateReportLive: privateReportLive ?? this.privateReportLive,
      );

  static const hidden = ProUtilityBoundaryModel(
    showHistory: false,
    showExport: false,
    showPrivateReportPreview: false,
    isPreviewOnly: false,
    shouldShowProBridge: false,
    reason: 'Pro utility hidden',
    exportLinkLive: false,
    privateReportLive: false,
  );
}

/// One utility row inside the single Pro utility card.
class ProUtilityRow {
  const ProUtilityRow({
    required this.title,
    required this.body,
    this.route,
    this.previewOnly = false,
  });

  final String title;
  final String body;
  final String? route;
  final bool previewOnly;
}
