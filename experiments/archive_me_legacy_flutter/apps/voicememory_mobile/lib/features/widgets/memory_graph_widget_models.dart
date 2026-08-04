enum MemoryGraphWidgetTheme { system, midnight, sunrise, highContrast }

class MemoryGraphWidgetPreferences {
  const MemoryGraphWidgetPreferences({
    this.theme = MemoryGraphWidgetTheme.system,
    this.quickCaptureEnabled = true,
    this.habitWidgetEnabled = true,
    this.clusterWidgetEnabled = true,
    this.lockScreenEnabled = false,
    this.selectedActionPlanIds = const {},
    this.selectedClusterIds = const {},
  });

  final MemoryGraphWidgetTheme theme;
  final bool quickCaptureEnabled;
  final bool habitWidgetEnabled;
  final bool clusterWidgetEnabled;
  final bool lockScreenEnabled;
  final Set<String> selectedActionPlanIds;
  final Set<String> selectedClusterIds;

  MemoryGraphWidgetPreferences copyWith({
    MemoryGraphWidgetTheme? theme,
    bool? quickCaptureEnabled,
    bool? habitWidgetEnabled,
    bool? clusterWidgetEnabled,
    bool? lockScreenEnabled,
    Set<String>? selectedActionPlanIds,
    Set<String>? selectedClusterIds,
  }) => MemoryGraphWidgetPreferences(
    theme: theme ?? this.theme,
    quickCaptureEnabled: quickCaptureEnabled ?? this.quickCaptureEnabled,
    habitWidgetEnabled: habitWidgetEnabled ?? this.habitWidgetEnabled,
    clusterWidgetEnabled: clusterWidgetEnabled ?? this.clusterWidgetEnabled,
    lockScreenEnabled: lockScreenEnabled ?? this.lockScreenEnabled,
    selectedActionPlanIds: selectedActionPlanIds ?? this.selectedActionPlanIds,
    selectedClusterIds: selectedClusterIds ?? this.selectedClusterIds,
  );

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'quickCaptureEnabled': quickCaptureEnabled,
    'habitWidgetEnabled': habitWidgetEnabled,
    'clusterWidgetEnabled': clusterWidgetEnabled,
    'lockScreenEnabled': lockScreenEnabled,
    'selectedActionPlanIds': selectedActionPlanIds.toList()..sort(),
    'selectedClusterIds': selectedClusterIds.toList()..sort(),
  };

  factory MemoryGraphWidgetPreferences.fromJson(Map<String, dynamic> json) {
    final theme = MemoryGraphWidgetTheme.values
        .where((value) => value.name == json['theme'])
        .firstOrNull;
    return MemoryGraphWidgetPreferences(
      theme: theme ?? MemoryGraphWidgetTheme.system,
      quickCaptureEnabled: json['quickCaptureEnabled'] != false,
      habitWidgetEnabled: json['habitWidgetEnabled'] != false,
      clusterWidgetEnabled: json['clusterWidgetEnabled'] != false,
      lockScreenEnabled: json['lockScreenEnabled'] == true,
      selectedActionPlanIds: _ids(json['selectedActionPlanIds']),
      selectedClusterIds: _ids(json['selectedClusterIds']),
    );
  }
}

class MemoryGraphWidgetStatus {
  const MemoryGraphWidgetStatus({
    required this.shareExtensionAvailable,
    required this.widgetExtensionAvailable,
    required this.sharedContainerAvailable,
    this.pendingShareCount = 0,
    this.lockScreenWidgetsSupported = false,
  });

  final bool shareExtensionAvailable;
  final bool widgetExtensionAvailable;
  final bool sharedContainerAvailable;
  final int pendingShareCount;
  final bool lockScreenWidgetsSupported;

  bool get ready =>
      shareExtensionAvailable &&
      widgetExtensionAvailable &&
      sharedContainerAvailable;

  factory MemoryGraphWidgetStatus.fromJson(Map<String, Object?> json) =>
      MemoryGraphWidgetStatus(
        shareExtensionAvailable: json['shareExtensionAvailable'] == true,
        widgetExtensionAvailable: json['widgetExtensionAvailable'] == true,
        sharedContainerAvailable: json['sharedContainerAvailable'] == true,
        pendingShareCount: (json['pendingShareCount'] as num?)?.toInt() ?? 0,
        lockScreenWidgetsSupported: json['lockScreenWidgetsSupported'] == true,
      );
}

Set<String> _ids(Object? value) {
  if (value is! List) return const {};
  return {
    for (final id in value.whereType<String>())
      if (id.trim().isNotEmpty && id.length <= 128) id.trim(),
  };
}
