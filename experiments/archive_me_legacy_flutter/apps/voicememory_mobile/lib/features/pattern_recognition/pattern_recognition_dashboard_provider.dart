import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exceptions.dart';
import '../../api/journal_sync_api_client.dart';
import '../../config/app_config.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services_providers.dart';
import '../insights/archive_insight.dart';

final journalSyncApiClientProvider = Provider<JournalSyncApiClient>(
  (ref) => ref.watch(appServicesProvider).journalSyncApi,
);

final patternRecognitionDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      PatternRecognitionDashboardController,
      PatternRecognitionDashboardState
    >(PatternRecognitionDashboardController.new);

class RecurringTopic {
  const RecurringTopic({required this.label, required this.count});

  final String label;
  final int count;
}

class MoodTrend {
  const MoodTrend({
    required this.mood,
    required this.count,
    required this.averageIntensity,
  });

  final String mood;
  final int count;
  final double averageIntensity;
}

class PatternRecognitionDashboardState {
  const PatternRecognitionDashboardState({
    required this.entries,
    required this.insights,
    required this.recurringTopics,
    required this.moodTrends,
    required this.loadedFromLocalFallback,
    this.isPro = false,
    this.backendRestricted = false,
  });

  final List<JournalEntry> entries;
  final ArchiveInsightsSnapshot insights;
  final List<RecurringTopic> recurringTopics;
  final List<MoodTrend> moodTrends;
  final bool loadedFromLocalFallback;
  final bool isPro;
  final bool backendRestricted;
}

class PatternRecognitionDashboardController
    extends AsyncNotifier<PatternRecognitionDashboardState> {
  @override
  Future<PatternRecognitionDashboardState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<PatternRecognitionDashboardState> _load() async {
    final entitlements = ref.watch(entitlementProvider).value;
    final localEntries = await ref.read(journalStoreProvider).loadAll();
    List<JournalEntry> entries;
    var localFallback = false;
    var backendRestricted =
        !AppConfig.isBackendConfigured || AppConfig.apiBaseUrl.isEmpty;
    if (backendRestricted) {
      entries = localEntries;
    } else {
      try {
        final remoteEntries = await ref
            .read(journalSyncApiClientProvider)
            .listJournal();
        entries = _mergeLocalAudio(remoteEntries, localEntries);
      } on BackendNotConfiguredException {
        entries = localEntries;
        backendRestricted = true;
      } on Object {
        if (localEntries.isEmpty) rethrow;
        entries = localEntries;
        localFallback = true;
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PatternRecognitionDashboardState(
      entries: entries,
      insights: ref
          .read(appServicesProvider)
          .archiveIntelligence
          .buildInsights(entries: entries),
      recurringTopics: _buildTopics(entries),
      moodTrends: _buildMoodTrends(entries),
      loadedFromLocalFallback: localFallback,
      isPro: entitlements?.isPro ?? false,
      backendRestricted: backendRestricted,
    );
  }

  static List<JournalEntry> _mergeLocalAudio(
    List<JournalEntry> remoteEntries,
    List<JournalEntry> localEntries,
  ) {
    final localById = {for (final entry in localEntries) entry.id: entry};
    final merged = remoteEntries.map((remote) {
      final local = localById[remote.id];
      final localPath = local?.localAudioPath;
      final localVaultRef = local?.localAudioVaultRef;
      if (remote.localAudioReference != null ||
          (localPath == null && localVaultRef == null)) {
        return remote;
      }
      final json = remote.toJson(includeLocalContext: true);
      if (localPath != null) json['localAudioPath'] = localPath;
      if (localVaultRef != null) {
        json['localAudioVaultRef'] = localVaultRef;
      }
      return JournalEntry.fromJson(json);
    }).toList();
    final remoteIds = remoteEntries.map((entry) => entry.id).toSet();
    merged.addAll(localEntries.where((entry) => !remoteIds.contains(entry.id)));
    return merged;
  }

  static List<RecurringTopic> _buildTopics(List<JournalEntry> entries) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final entry in entries) {
      for (final rawTheme in entry.reflection.recurringThemes) {
        final label = rawTheme.trim();
        if (label.isEmpty) continue;
        final key = label.toLowerCase();
        labels.putIfAbsent(key, () => label);
        counts.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final topics =
        counts.entries
            .map(
              (item) => RecurringTopic(
                label: labels[item.key] ?? item.key,
                count: item.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final countOrder = b.count.compareTo(a.count);
            return countOrder != 0 ? countOrder : a.label.compareTo(b.label);
          });
    return topics.take(6).toList(growable: false);
  }

  static List<MoodTrend> _buildMoodTrends(List<JournalEntry> entries) {
    final totals = <String, ({int count, int intensity})>{};
    final labels = <String, String>{};
    for (final entry in entries) {
      final mood = entry.reflection.mood.trim();
      if (mood.isEmpty) continue;
      final key = mood.toLowerCase();
      labels.putIfAbsent(key, () => mood);
      final previous = totals[key] ?? (count: 0, intensity: 0);
      totals[key] = (
        count: previous.count + 1,
        intensity:
            previous.intensity +
            entry.reflection.emotionalIntensity.clamp(0, 5),
      );
    }
    final trends =
        totals.entries
            .map(
              (item) => MoodTrend(
                mood: labels[item.key] ?? item.key,
                count: item.value.count,
                averageIntensity: item.value.intensity / item.value.count,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return trends.take(5).toList(growable: false);
  }
}
