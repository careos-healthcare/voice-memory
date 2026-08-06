import 'package:flutter/foundation.dart';

import '../app_review/archive_app_review_access_gate.dart';

enum ArchiveActivationFunnelEventType {
  mapSurfaceShown,
  firstRecordingStarted,
  firstRecordingCompleted,
  firstPreviewShown,
  guidedPromptSelected,
  secondRecordingStarted,
  secondRecordingCompleted,
  secondPreviewShown,
  thirdRecordingStarted,
  thirdRecordingCompleted,
  fullMapShown,
  nodeConfirmedOrEdited,
  returnProofCreated,
  returnRecordingStarted,
  returnRecordingCompleted,
  returnResultShown,
  paywallShown,
  paywallDismissed,
  paidIntentSubmitted,
}

class ArchiveActivationFunnelEvent {
  const ArchiveActivationFunnelEvent({
    required this.id,
    required this.createdAt,
    required this.type,
    this.entryId,
    this.mapId,
    this.proofId,
    this.source,
    this.metadata = const {},
  });

  final String id;
  final DateTime createdAt;
  final ArchiveActivationFunnelEventType type;
  final String? entryId;
  final String? mapId;
  final String? proofId;
  final String? source;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'type': type.name,
    if (entryId != null && entryId!.isNotEmpty) 'entryId': entryId,
    if (mapId != null && mapId!.isNotEmpty) 'mapId': mapId,
    if (proofId != null && proofId!.isNotEmpty) 'proofId': proofId,
    if (source != null && source!.isNotEmpty) 'source': source,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  static ArchiveActivationFunnelEvent? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (createdAt == null) return null;
    final type = _typeFromName(json['type']?.toString());
    if (type == null) return null;
    final rawMetadata = json['metadata'];
    final metadata = <String, String>{};
    if (rawMetadata is Map) {
      for (final entry in rawMetadata.entries) {
        metadata[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return ArchiveActivationFunnelEvent(
      id: id,
      createdAt: createdAt,
      type: type,
      entryId: json['entryId']?.toString(),
      mapId: json['mapId']?.toString(),
      proofId: json['proofId']?.toString(),
      source: json['source']?.toString(),
      metadata: metadata,
    );
  }

  static ArchiveActivationFunnelEventType? _typeFromName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in ArchiveActivationFunnelEventType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class ArchiveActivationFunnelSummary {
  const ArchiveActivationFunnelSummary({
    required this.totalEvents,
    required this.mapSurfaceShownCount,
    required this.firstRecordingStartedCount,
    required this.firstRecordingCompletedCount,
    required this.firstPreviewShownCount,
    required this.secondRecordingCompletedCount,
    required this.thirdRecordingCompletedCount,
    required this.fullMapShownCount,
    required this.nodeConfirmedOrEditedCount,
    required this.returnProofCreatedCount,
    required this.returnRecordingCompletedCount,
    required this.returnResultShownCount,
    required this.paywallShownCount,
    required this.paidIntentSubmittedCount,
    required this.firstRecordingCompletionRate,
    required this.threeRecordingCompletionRate,
    required this.fullMapReachRate,
    required this.returnCompletionRate,
    required this.paidIntentFeedbackRate,
    required this.strongestDropOffLabel,
    required this.activationReadinessLabel,
    required this.secondRecordingStartedCount,
    required this.returnRecordingStartedCount,
  });

  final int totalEvents;
  final int mapSurfaceShownCount;
  final int firstRecordingStartedCount;
  final int firstRecordingCompletedCount;
  final int firstPreviewShownCount;
  final int secondRecordingStartedCount;
  final int secondRecordingCompletedCount;
  final int thirdRecordingCompletedCount;
  final int fullMapShownCount;
  final int nodeConfirmedOrEditedCount;
  final int returnProofCreatedCount;
  final int returnRecordingStartedCount;
  final int returnRecordingCompletedCount;
  final int returnResultShownCount;
  final int paywallShownCount;
  final int paidIntentSubmittedCount;
  final double firstRecordingCompletionRate;
  final double threeRecordingCompletionRate;
  final double fullMapReachRate;
  final double returnCompletionRate;
  final double paidIntentFeedbackRate;
  final String strongestDropOffLabel;
  final String activationReadinessLabel;

  bool get hasData => totalEvents > 0;
}

abstract class ArchiveActivationFunnelSummaryResolver {
  ArchiveActivationFunnelSummaryResolver._();

  static const tooEarlyLabel = 'Too early';
  static const weakLabel = 'Weak activation';
  static const promisingLabel = 'Promising activation';
  static const strongLabel = 'Strong activation';

  static const dropOffStartNotFinish =
      'Users start recording but do not finish';
  static const dropOffPreviewNoSecond =
      'Users see the first preview but do not add a second moment';
  static const dropOffRecordingsNoMap =
      'Users complete recordings but do not reach the full map';
  static const dropOffMapNoReturn = 'Users see the map but do not return';
  static const dropOffPaywallNoFeedback =
      'Users see the paywall but do not leave paid-intent feedback';
  static const dropOffNone = 'No clear drop-off yet';

  static ArchiveActivationFunnelSummary summarize(
    List<ArchiveActivationFunnelEvent> events,
  ) {
    final counts = <ArchiveActivationFunnelEventType, int>{};
    for (final type in ArchiveActivationFunnelEventType.values) {
      counts[type] = 0;
    }
    for (final event in events) {
      counts[event.type] = (counts[event.type] ?? 0) + 1;
    }

    final firstStarted =
        counts[ArchiveActivationFunnelEventType.firstRecordingStarted] ?? 0;
    final firstCompleted =
        counts[ArchiveActivationFunnelEventType.firstRecordingCompleted] ?? 0;
    final firstPreview =
        counts[ArchiveActivationFunnelEventType.firstPreviewShown] ?? 0;
    final secondStarted =
        counts[ArchiveActivationFunnelEventType.secondRecordingStarted] ?? 0;
    final thirdCompleted =
        counts[ArchiveActivationFunnelEventType.thirdRecordingCompleted] ?? 0;
    final fullMap = counts[ArchiveActivationFunnelEventType.fullMapShown] ?? 0;
    final returnProof =
        counts[ArchiveActivationFunnelEventType.returnProofCreated] ?? 0;
    final returnCompleted =
        counts[ArchiveActivationFunnelEventType.returnRecordingCompleted] ?? 0;
    final paywallShown =
        counts[ArchiveActivationFunnelEventType.paywallShown] ?? 0;
    final paidIntent =
        counts[ArchiveActivationFunnelEventType.paidIntentSubmitted] ?? 0;

    final firstRate = _rate(firstCompleted, firstStarted);
    final threeRate = _rate(thirdCompleted, firstStarted);
    final mapRate = _rate(fullMap, firstStarted);
    final returnRate = _rate(returnCompleted, returnProof);
    final paidRate = _rate(paidIntent, paywallShown);

    final readiness = _readinessLabel(
      firstStarted: firstStarted,
      threeRate: threeRate,
      mapRate: mapRate,
    );
    final dropOff = _strongestDropOff(
      firstStarted: firstStarted,
      firstCompleted: firstCompleted,
      firstPreview: firstPreview,
      secondStarted: secondStarted,
      thirdCompleted: thirdCompleted,
      fullMap: fullMap,
      returnProof: returnProof,
      paywallShown: paywallShown,
      paidIntent: paidIntent,
    );

    final summary = ArchiveActivationFunnelSummary(
      totalEvents: events.length,
      mapSurfaceShownCount:
          counts[ArchiveActivationFunnelEventType.mapSurfaceShown] ?? 0,
      firstRecordingStartedCount: firstStarted,
      firstRecordingCompletedCount: firstCompleted,
      firstPreviewShownCount: firstPreview,
      secondRecordingStartedCount: secondStarted,
      secondRecordingCompletedCount:
          counts[ArchiveActivationFunnelEventType.secondRecordingCompleted] ??
          0,
      thirdRecordingCompletedCount: thirdCompleted,
      fullMapShownCount: fullMap,
      nodeConfirmedOrEditedCount:
          counts[ArchiveActivationFunnelEventType.nodeConfirmedOrEdited] ?? 0,
      returnProofCreatedCount: returnProof,
      returnRecordingStartedCount:
          counts[ArchiveActivationFunnelEventType.returnRecordingStarted] ?? 0,
      returnRecordingCompletedCount: returnCompleted,
      returnResultShownCount:
          counts[ArchiveActivationFunnelEventType.returnResultShown] ?? 0,
      paywallShownCount: paywallShown,
      paidIntentSubmittedCount: paidIntent,
      firstRecordingCompletionRate: firstRate,
      threeRecordingCompletionRate: threeRate,
      fullMapReachRate: mapRate,
      returnCompletionRate: returnRate,
      paidIntentFeedbackRate: paidRate,
      strongestDropOffLabel: dropOff,
      activationReadinessLabel: readiness,
    );

    ArchiveActivationFunnelLog.summaryReady(
      readiness: summary.activationReadinessLabel,
    );
    return summary;
  }

  static double _rate(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }

  static String _readinessLabel({
    required int firstStarted,
    required double threeRate,
    required double mapRate,
  }) {
    if (firstStarted < 10) return tooEarlyLabel;
    if (threeRate >= 0.70 && mapRate >= 0.60) return strongLabel;
    if (threeRate >= 0.50 && mapRate >= 0.50) return promisingLabel;
    if (threeRate < 0.40) return weakLabel;
    return weakLabel;
  }

  static String _strongestDropOff({
    required int firstStarted,
    required int firstCompleted,
    required int firstPreview,
    required int secondStarted,
    required int thirdCompleted,
    required int fullMap,
    required int returnProof,
    required int paywallShown,
    required int paidIntent,
  }) {
    final candidates = <(double, String)>[];
    if (firstStarted > 0) {
      final gap = 1 - _rate(firstCompleted, firstStarted);
      if (gap >= 0.25) candidates.add((gap, dropOffStartNotFinish));
    }
    if (firstPreview > 0) {
      final gap = 1 - _rate(secondStarted, firstPreview);
      if (gap >= 0.25) candidates.add((gap, dropOffPreviewNoSecond));
    }
    if (thirdCompleted > 0) {
      final gap = 1 - _rate(fullMap, thirdCompleted);
      if (gap >= 0.25) candidates.add((gap, dropOffRecordingsNoMap));
    }
    if (fullMap > 0) {
      final gap = 1 - _rate(returnProof, fullMap);
      if (gap >= 0.25) candidates.add((gap, dropOffMapNoReturn));
    }
    if (paywallShown > 0) {
      final gap = 1 - _rate(paidIntent, paywallShown);
      if (gap >= 0.25) candidates.add((gap, dropOffPaywallNoFeedback));
    }
    if (candidates.isEmpty) return dropOffNone;
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    return candidates.first.$2;
  }
}

abstract class ArchiveActivationFunnelPlacement {
  ArchiveActivationFunnelPlacement._();

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  @visibleForTesting
  static bool? blockForTest;

  static bool shouldTrack() {
    if (blockForTest != null) return !blockForTest!;
    if (ArchiveAppReviewAccessGate.isEnabled) return false;
    if (_releaseSmokeFromEnvironment) return false;
    return true;
  }
}

abstract class ArchiveActivationFunnelCoordinator {
  ArchiveActivationFunnelCoordinator._();

  static final Set<String> _sessionShownKeys = <String>{};

  @visibleForTesting
  static void resetSessionForTest() {
    _sessionShownKeys.clear();
  }

  static const shownEventTypes = <ArchiveActivationFunnelEventType>{
    ArchiveActivationFunnelEventType.mapSurfaceShown,
    ArchiveActivationFunnelEventType.firstPreviewShown,
    ArchiveActivationFunnelEventType.secondPreviewShown,
    ArchiveActivationFunnelEventType.fullMapShown,
    ArchiveActivationFunnelEventType.returnResultShown,
    ArchiveActivationFunnelEventType.paywallShown,
  };

  static Future<void> track({
    required Future<void> Function(ArchiveActivationFunnelEvent event) persist,
    required ArchiveActivationFunnelEventType type,
    String? entryId,
    String? mapId,
    String? proofId,
    String? source,
    Map<String, String>? metadata,
    bool dedupeShownPerSession = true,
  }) async {
    if (!ArchiveActivationFunnelPlacement.shouldTrack()) return;
    if (dedupeShownPerSession && shownEventTypes.contains(type)) {
      final dedupeKey = '${type.name}:${source ?? 'default'}';
      if (_sessionShownKeys.contains(dedupeKey)) return;
      _sessionShownKeys.add(dedupeKey);
    }
    final event = ArchiveActivationFunnelEvent(
      id: 'aaf-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      type: type,
      entryId: entryId,
      mapId: mapId,
      proofId: proofId,
      source: source,
      metadata: metadata ?? const {},
    );
    ArchiveActivationFunnelLog.event(type: type);
    await persist(event);
  }
}

abstract class ArchiveActivationFunnelLog {
  ArchiveActivationFunnelLog._();

  static void event({required ArchiveActivationFunnelEventType type}) {
    debugPrint('ARCHIVEME_ACTIVATION_FUNNEL_EVENT type=${type.name}');
  }

  static void summaryReady({required String readiness}) {
    debugPrint(
      'ARCHIVEME_ACTIVATION_FUNNEL_SUMMARY_READY readiness=$readiness',
    );
  }

  static void exportTapped() {
    debugPrint('ARCHIVEME_ACTIVATION_FUNNEL_EXPORT_TAPPED');
  }
}
