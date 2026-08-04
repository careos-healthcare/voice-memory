import '../../storage/mobile_prefs_store.dart';

enum DiscoverableFeature {
  insightsReady,
  lifeStory,
  archiveIntelligence;

  String get storageId => switch (this) {
    insightsReady => 'insights_ready',
    lifeStory => 'life_story',
    archiveIntelligence => 'archive_intelligence',
  };
}

enum FeatureDiscoveryMoment { afterEntryProcessed, dashboard }

class FeatureDiscoveryContext {
  const FeatureDiscoveryContext({
    required this.moment,
    required this.entryCount,
  });

  final FeatureDiscoveryMoment moment;
  final int entryCount;
}

class FeatureDiscoverySuggestion {
  const FeatureDiscoverySuggestion({
    required this.feature,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.route,
    required this.reason,
  });

  final DiscoverableFeature feature;
  final String title;
  final String message;
  final String actionLabel;
  final String route;
  final String reason;
}

/// Persistent, deterministic feature-discovery policy.
///
/// Suggestions are one-time and dismissible. The service never opens a route
/// itself, interrupts capture, or displays modal UI.
class FeatureDiscoveryService {
  factory FeatureDiscoveryService({
    required MobilePrefsStore prefs,
    DateTime Function()? clock,
  }) {
    return FeatureDiscoveryService._(prefs, clock ?? DateTime.now);
  }

  FeatureDiscoveryService._(this._prefs, this._clock);

  static const storageKey = 'contextualFeatureDiscoveryV1';

  final MobilePrefsStore _prefs;
  final DateTime Function() _clock;

  Future<FeatureDiscoverySuggestion?> nextSuggestion(
    FeatureDiscoveryContext context,
  ) async {
    for (final feature in _candidates(context)) {
      if (!await _isAvailable(feature)) continue;
      return _suggestion(feature, context.entryCount);
    }
    return null;
  }

  Future<void> markExposed(DiscoverableFeature feature) {
    return _updateFeature(feature, (current) {
      return {
        ...current,
        'exposureCount': ((current['exposureCount'] as num?)?.toInt() ?? 0) + 1,
        'lastExposedAt': _clock().toUtc().toIso8601String(),
      };
    });
  }

  Future<void> dismiss(DiscoverableFeature feature) {
    return _updateFeature(feature, (current) {
      return {
        ...current,
        'dismissed': true,
        'dismissedAt': _clock().toUtc().toIso8601String(),
      };
    });
  }

  Future<void> complete(DiscoverableFeature feature) {
    return _updateFeature(feature, (current) {
      return {
        ...current,
        'completed': true,
        'completedAt': _clock().toUtc().toIso8601String(),
      };
    });
  }

  Future<Map<String, dynamic>> stateForTest() async =>
      await _prefs.readMap(storageKey) ?? const <String, dynamic>{};

  Future<void> resetForTest() => _prefs.remove(storageKey);

  Iterable<DiscoverableFeature> _candidates(
    FeatureDiscoveryContext context,
  ) sync* {
    if (context.moment == FeatureDiscoveryMoment.afterEntryProcessed) {
      if (context.entryCount >= 1) {
        yield DiscoverableFeature.insightsReady;
      }
      if (context.entryCount >= 3) {
        yield DiscoverableFeature.lifeStory;
      }
      if (context.entryCount >= 5) {
        yield DiscoverableFeature.archiveIntelligence;
      }
      return;
    }
    if (context.entryCount >= 3) {
      yield DiscoverableFeature.lifeStory;
    }
    if (context.entryCount >= 5) {
      yield DiscoverableFeature.archiveIntelligence;
    }
  }

  Future<bool> _isAvailable(DiscoverableFeature feature) async {
    final state = await _prefs.readMap(storageKey);
    final raw = state?[feature.storageId];
    final featureState = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return featureState['dismissed'] != true &&
        featureState['completed'] != true &&
        ((featureState['exposureCount'] as num?)?.toInt() ?? 0) == 0;
  }

  FeatureDiscoverySuggestion _suggestion(
    DiscoverableFeature feature,
    int entryCount,
  ) {
    return switch (feature) {
      DiscoverableFeature.insightsReady => const FeatureDiscoverySuggestion(
        feature: DiscoverableFeature.insightsReady,
        title: 'Insights ready',
        message:
            'Your voice entry has been processed. See what ArchiveMe noticed.',
        actionLabel: 'View insights',
        route: '/archive-belief',
        reason: 'entry_processed',
      ),
      DiscoverableFeature.lifeStory => FeatureDiscoverySuggestion(
        feature: DiscoverableFeature.lifeStory,
        title: 'Your Life Story is taking shape',
        message:
            '$entryCount entries can now begin connecting into chapters, '
            'people, beliefs, and changes.',
        actionLabel: 'Open Life Story',
        route: '/life-os',
        reason: 'journal_milestone_3',
      ),
      DiscoverableFeature.archiveIntelligence => FeatureDiscoverySuggestion(
        feature: DiscoverableFeature.archiveIntelligence,
        title: 'Explore Archive Intelligence',
        message:
            '$entryCount entries can reveal deeper patterns, '
            'contradictions, and changes.',
        actionLabel: 'Open Archive Intelligence',
        route: '/archive-analyst',
        reason: 'journal_milestone_5',
      ),
    };
  }

  Future<void> _updateFeature(
    DiscoverableFeature feature,
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) async {
    await _prefs.updateMap(storageKey, (current) {
      final state = {...?current};
      final raw = state[feature.storageId];
      final featureState = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      state[feature.storageId] = transform(featureState);
      return state;
    });
  }
}
