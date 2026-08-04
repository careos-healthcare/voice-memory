enum MuseFrequency {
  twiceDaily(12),
  daily(24),
  everyTwoDays(48),
  weekly(168);

  const MuseFrequency(this.hours);
  final int hours;
}

final class MuseGovernance {
  const MuseGovernance({
    this.enabled = true,
    this.runOnlyWhenCharging = true,
    this.requireWifi = true,
    this.requireIdle = true,
    this.minimumBatteryPercent = 35,
    this.frequency = MuseFrequency.daily,
  });

  final bool enabled;
  final bool runOnlyWhenCharging;
  final bool requireWifi;
  final bool requireIdle;
  final int minimumBatteryPercent;
  final MuseFrequency frequency;

  MuseGovernance copyWith({
    bool? enabled,
    bool? runOnlyWhenCharging,
    bool? requireWifi,
    bool? requireIdle,
    int? minimumBatteryPercent,
    MuseFrequency? frequency,
  }) => MuseGovernance(
    enabled: enabled ?? this.enabled,
    runOnlyWhenCharging: runOnlyWhenCharging ?? this.runOnlyWhenCharging,
    requireWifi: requireWifi ?? this.requireWifi,
    requireIdle: requireIdle ?? this.requireIdle,
    minimumBatteryPercent: minimumBatteryPercent ?? this.minimumBatteryPercent,
    frequency: frequency ?? this.frequency,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'runOnlyWhenCharging': runOnlyWhenCharging,
    'requireWifi': requireWifi,
    'requireIdle': requireIdle,
    'minimumBatteryPercent': minimumBatteryPercent,
    'frequency': frequency.name,
  };

  factory MuseGovernance.fromJson(Map<String, dynamic> json) => MuseGovernance(
    enabled: json['enabled'] as bool? ?? true,
    runOnlyWhenCharging: json['runOnlyWhenCharging'] as bool? ?? true,
    requireWifi: json['requireWifi'] as bool? ?? true,
    requireIdle: json['requireIdle'] as bool? ?? true,
    minimumBatteryPercent:
        ((json['minimumBatteryPercent'] as num?)?.toInt() ?? 35).clamp(10, 100),
    frequency:
        MuseFrequency.values
            .where((value) => value.name == json['frequency'])
            .firstOrNull ??
        MuseFrequency.daily,
  );
}

final class MuseResourceState {
  const MuseResourceState({
    required this.isCharging,
    required this.isWifiConnected,
    required this.isIdle,
    required this.batteryPercent,
  });

  const MuseResourceState.schedulerGuaranteed()
    : isCharging = true,
      isWifiConnected = true,
      isIdle = true,
      batteryPercent = 100;

  final bool isCharging;
  final bool isWifiConnected;
  final bool isIdle;
  final int batteryPercent;

  bool allows(MuseGovernance settings) =>
      (!settings.runOnlyWhenCharging || isCharging) &&
      (!settings.requireWifi || isWifiConnected) &&
      (!settings.requireIdle || isIdle) &&
      batteryPercent >= settings.minimumBatteryPercent;
}

final class MuseBridgeDiscovery {
  MuseBridgeDiscovery({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.sourceLabel,
    required this.targetLabel,
    required this.sourceYear,
    required this.targetYear,
    required this.similarity,
    required this.createdAt,
  });

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String sourceLabel;
  final String targetLabel;
  final int sourceYear;
  final int targetYear;
  final double similarity;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'sourceNodeId': sourceNodeId,
    'targetNodeId': targetNodeId,
    'sourceLabel': sourceLabel,
    'targetLabel': targetLabel,
    'sourceYear': sourceYear,
    'targetYear': targetYear,
    'similarity': similarity,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory MuseBridgeDiscovery.fromJson(Map<String, dynamic> json) =>
      MuseBridgeDiscovery(
        id: json['id'] as String? ?? '',
        sourceNodeId: json['sourceNodeId'] as String? ?? '',
        targetNodeId: json['targetNodeId'] as String? ?? '',
        sourceLabel: json['sourceLabel'] as String? ?? '',
        targetLabel: json['targetLabel'] as String? ?? '',
        sourceYear: (json['sourceYear'] as num?)?.toInt() ?? 0,
        targetYear: (json['targetYear'] as num?)?.toInt() ?? 0,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

final class MuseBriefing {
  MuseBriefing({
    required this.id,
    required this.localDay,
    required this.discoveries,
    required this.summary,
    this.actionPrompt,
    this.actionPlanId,
  });

  final String id;
  final DateTime localDay;
  final List<MuseBridgeDiscovery> discoveries;
  final String summary;
  final String? actionPrompt;
  final String? actionPlanId;

  MuseBridgeDiscovery? get serendipity => discoveries
      .where((item) => item.sourceYear != item.targetYear)
      .firstOrNull;

  Map<String, Object?> toJson() => {
    'id': id,
    'localDay': localDay.toIso8601String(),
    'discoveries': discoveries.map((item) => item.toJson()).toList(),
    'summary': summary,
    'actionPrompt': actionPrompt,
    'actionPlanId': actionPlanId,
  };

  factory MuseBriefing.fromJson(Map<String, dynamic> json) => MuseBriefing(
    id: json['id'] as String? ?? '',
    localDay:
        DateTime.tryParse(json['localDay'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    discoveries: (json['discoveries'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              MuseBridgeDiscovery.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    summary: json['summary'] as String? ?? '',
    actionPrompt: json['actionPrompt'] as String?,
    actionPlanId: json['actionPlanId'] as String?,
  );
}

enum MuseSweepStatus {
  completed,
  skippedDisabled,
  skippedResources,
  skippedDue,
}

final class MuseSweepResult {
  const MuseSweepResult({
    required this.status,
    this.briefing,
    this.createdBridgeCount = 0,
  });

  final MuseSweepStatus status;
  final MuseBriefing? briefing;
  final int createdBridgeCount;
}

enum LegacyBridgeSuggestionStatus { pending, accepted, rejected, autoLinked }

final class LegacyBridgeSuggestion {
  LegacyBridgeSuggestion({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.sourceLabel,
    required this.targetLabel,
    required Iterable<String> entities,
    required this.confidenceScore,
    required this.rationale,
    required this.sourceExcerpt,
    this.targetExcerpt = '',
    this.rationaleConfidence = 1,
    Iterable<String> tags = const [],
    DateTime? deferredUntil,
    required DateTime createdAt,
    this.status = LegacyBridgeSuggestionStatus.pending,
    DateTime? resolvedAt,
  }) : entities = List.unmodifiable(entities),
       tags = Set.unmodifiable(tags),
       createdAt = createdAt.toUtc(),
       resolvedAt = resolvedAt?.toUtc(),
       deferredUntil = deferredUntil?.toUtc();

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String sourceLabel;
  final String targetLabel;
  final List<String> entities;
  final double confidenceScore;
  final String rationale;
  final String sourceExcerpt;
  final String targetExcerpt;
  final double rationaleConfidence;
  final Set<String> tags;
  final DateTime? deferredUntil;
  final DateTime createdAt;
  final LegacyBridgeSuggestionStatus status;
  final DateTime? resolvedAt;

  LegacyBridgeSuggestion resolve(
    LegacyBridgeSuggestionStatus value,
    DateTime at,
  ) => LegacyBridgeSuggestion(
    id: id,
    sourceNodeId: sourceNodeId,
    targetNodeId: targetNodeId,
    sourceLabel: sourceLabel,
    targetLabel: targetLabel,
    entities: entities,
    confidenceScore: confidenceScore,
    rationale: rationale,
    sourceExcerpt: sourceExcerpt,
    targetExcerpt: targetExcerpt,
    rationaleConfidence: rationaleConfidence,
    tags: tags,
    deferredUntil: deferredUntil,
    createdAt: createdAt,
    status: value,
    resolvedAt: at,
  );

  LegacyBridgeSuggestion deferUntil(DateTime value) => LegacyBridgeSuggestion(
    id: id,
    sourceNodeId: sourceNodeId,
    targetNodeId: targetNodeId,
    sourceLabel: sourceLabel,
    targetLabel: targetLabel,
    entities: entities,
    confidenceScore: confidenceScore,
    rationale: rationale,
    sourceExcerpt: sourceExcerpt,
    targetExcerpt: targetExcerpt,
    rationaleConfidence: rationaleConfidence,
    tags: tags,
    deferredUntil: value,
    createdAt: createdAt,
    status: status,
    resolvedAt: resolvedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceNodeId': sourceNodeId,
    'targetNodeId': targetNodeId,
    'sourceLabel': sourceLabel,
    'targetLabel': targetLabel,
    'entities': entities,
    'confidenceScore': confidenceScore,
    'rationale': rationale,
    'sourceExcerpt': sourceExcerpt,
    'targetExcerpt': targetExcerpt,
    'rationaleConfidence': rationaleConfidence,
    'tags': tags.toList()..sort(),
    'deferredUntil': deferredUntil?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory LegacyBridgeSuggestion.fromJson(Map<String, dynamic> json) =>
      LegacyBridgeSuggestion(
        id: json['id'] as String? ?? '',
        sourceNodeId: json['sourceNodeId'] as String? ?? '',
        targetNodeId: json['targetNodeId'] as String? ?? '',
        sourceLabel: json['sourceLabel'] as String? ?? '',
        targetLabel: json['targetLabel'] as String? ?? '',
        entities: (json['entities'] as List? ?? const []).whereType<String>(),
        confidenceScore:
            (json['confidenceScore'] as num?)?.toDouble().clamp(0, 1) ?? 0,
        rationale: json['rationale'] as String? ?? '',
        sourceExcerpt: json['sourceExcerpt'] as String? ?? '',
        targetExcerpt: json['targetExcerpt'] as String? ?? '',
        rationaleConfidence:
            (json['rationaleConfidence'] as num?)?.toDouble().clamp(0, 1) ?? 1,
        tags: (json['tags'] as List? ?? const []).whereType<String>(),
        deferredUntil: DateTime.tryParse(
          json['deferredUntil'] as String? ?? '',
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        status:
            LegacyBridgeSuggestionStatus.values
                .where((value) => value.name == json['status'])
                .firstOrNull ??
            LegacyBridgeSuggestionStatus.pending,
        resolvedAt: DateTime.tryParse(json['resolvedAt'] as String? ?? ''),
      );
}

enum LegacySweepStatus {
  idle,
  queued,
  running,
  pausedThermal,
  completed,
  failed,
}

final class LegacySweepProgress {
  const LegacySweepProgress({
    required this.status,
    required this.totalNodes,
    required this.analyzedNodes,
    required this.connectionsForged,
    required this.startedAt,
    this.updatedAt,
    this.error,
  });

  const LegacySweepProgress.idle()
    : status = LegacySweepStatus.idle,
      totalNodes = 0,
      analyzedNodes = 0,
      connectionsForged = 0,
      startedAt = null,
      updatedAt = null,
      error = null;

  final LegacySweepStatus status;
  final int totalNodes;
  final int analyzedNodes;
  final int connectionsForged;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final String? error;

  double get fraction => totalNodes == 0
      ? (status == LegacySweepStatus.completed ? 1 : 0)
      : (analyzedNodes / totalNodes).clamp(0, 1);

  Duration? get estimatedRemaining {
    final started = startedAt;
    final updated = updatedAt;
    if (started == null ||
        updated == null ||
        analyzedNodes <= 0 ||
        analyzedNodes >= totalNodes) {
      return null;
    }
    final microsPerNode =
        updated.difference(started).inMicroseconds / analyzedNodes;
    return Duration(
      microseconds: ((totalNodes - analyzedNodes) * microsPerNode).round(),
    );
  }

  Map<String, Object?> toJson() => {
    'status': status.name,
    'totalNodes': totalNodes,
    'analyzedNodes': analyzedNodes,
    'connectionsForged': connectionsForged,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'error': error,
  };

  factory LegacySweepProgress.fromJson(Map<String, dynamic> json) =>
      LegacySweepProgress(
        status:
            LegacySweepStatus.values
                .where((value) => value.name == json['status'])
                .firstOrNull ??
            LegacySweepStatus.idle,
        totalNodes: (json['totalNodes'] as num?)?.toInt() ?? 0,
        analyzedNodes: (json['analyzedNodes'] as num?)?.toInt() ?? 0,
        connectionsForged: (json['connectionsForged'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        error: json['error'] as String?,
      );
}
