import 'dart:async';
import 'dart:typed_data';

import 'package:workmanager/workmanager.dart';

import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import '../action_plans/action_plan_models.dart';
import '../action_plans/action_plan_store.dart';
import '../connectors/healthkit_connector.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'morning_briefing_models.dart';
import 'morning_briefing_store.dart';
import 'morning_briefing_synthesis_service.dart';

abstract interface class MorningBriefingScheduler {
  Future<void> schedule(DateTime nextLocalRun);
  Future<void> cancel();
}

class WorkmanagerMorningBriefingScheduler implements MorningBriefingScheduler {
  static const taskName = 'archiveMe.morningBriefing.generate';
  static const uniqueName = 'com.voicememory.mobile.morning.briefing';

  WorkmanagerMorningBriefingScheduler({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<void> schedule(DateTime nextLocalRun) =>
      Workmanager().registerOneOffTask(
        uniqueName,
        taskName,
        initialDelay: nextLocalRun.difference(_clock()),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(requiresBatteryNotLow: true),
      );

  @override
  Future<void> cancel() => Workmanager().cancelByUniqueName(uniqueName);
}

class MorningBriefingService {
  MorningBriefingService({
    required this.journalStore,
    required this.actionPlanStore,
    required this.clusterStore,
    required this.store,
    required this.audioStorage,
    required this.synthesizer,
    this.healthDataSource,
    this.isHealthEnabled,
    this.preferencesStore,
    this.scheduler,
    this.museTriageCount,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const preferenceKey = 'morning_briefing_settings_v1';
  final JournalStore journalStore;
  final ActionPlanStore actionPlanStore;
  final SemanticClusterStore clusterStore;
  final HealthDataSource? healthDataSource;
  final Future<bool> Function()? isHealthEnabled;
  final MorningBriefingStore store;
  final EncryptedMorningBriefingAudioStorage audioStorage;
  final MorningBriefingSynthesizer synthesizer;
  final MobilePrefsStore? preferencesStore;
  final MorningBriefingScheduler? scheduler;
  final int Function()? museTriageCount;
  final DateTime Function() _clock;
  bool _generating = false;

  Future<MorningBriefingPreferences> preferences() async {
    final value = await preferencesStore?.readMap(preferenceKey);
    int integer(String key, int fallback, int min, int max) {
      final raw = value?[key];
      final parsed = raw is num ? raw.toInt() : fallback;
      return parsed.clamp(min, max);
    }

    return MorningBriefingPreferences(
      enabled: value?['enabled'] is bool ? value!['enabled'] as bool : true,
      hour: integer('hour', 7, 0, 23),
      minute: integer('minute', 0, 0, 59),
      quietHoursStart: integer('quietHoursStart', 22, 0, 23),
      quietHoursEnd: integer('quietHoursEnd', 7, 0, 23),
    );
  }

  Future<void> updatePreferences(MorningBriefingPreferences value) async {
    await preferencesStore?.writeMap(preferenceKey, {
      'enabled': value.enabled,
      'hour': value.hour,
      'minute': value.minute,
      'quietHoursStart': value.quietHoursStart,
      'quietHoursEnd': value.quietHoursEnd,
    });
    if (!value.enabled) {
      await scheduler?.cancel();
      return;
    }
    await scheduler?.schedule(value.nextRunAfter(_clock()));
  }

  Future<void> scheduleNext() async {
    final settings = await preferences();
    if (!settings.enabled) {
      await scheduler?.cancel();
      return;
    }
    await scheduler?.schedule(settings.nextRunAfter(_clock()));
  }

  Future<bool> isDue({DateTime? now}) async {
    final current = (now ?? _clock()).toLocal();
    final settings = await preferences();
    if (!settings.enabled || settings.isQuietAt(current)) return false;
    final scheduled = DateTime(
      current.year,
      current.month,
      current.day,
      settings.hour,
      settings.minute,
    );
    return !current.isBefore(scheduled) && await store.forDay(current) == null;
  }

  Future<MorningBriefing?> generateIfDue({
    bool force = false,
    DateTime? now,
  }) async {
    if (_generating) return null;
    final current = (now ?? _clock()).toLocal();
    if (!force && !await isDue(now: current)) return store.forDay(current);
    _generating = true;
    try {
      final payload = await aggregate(current);
      final result = await synthesizer.synthesize(payload);
      final audio = result.audioBytes;
      var briefing = result.briefing;
      briefing = briefing.copyWith(museTriageCount: payload.museTriageCount);
      if (audio != null && audio.isNotEmpty) {
        try {
          await audioStorage.write(briefing.id, audio);
          briefing = briefing.copyWith(encryptedAudioAvailable: true);
        } finally {
          audio.fillRange(0, audio.length, 0);
        }
      }
      await store.save(
        briefing,
        clusterVelocities: {
          for (final cluster in payload.clusterSignals)
            cluster.clusterId: cluster.velocity,
        },
      );
      return briefing;
    } finally {
      _generating = false;
      unawaited(scheduleNext());
    }
  }

  Future<MorningBriefingPayload> aggregate(DateTime localNow) async {
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entries = (await journalStore.loadAll()).where((entry) {
      final local = entry.createdAt.toLocal();
      return !local.isBefore(yesterday) && local.isBefore(today);
    }).toList();
    final plans = await actionPlanStore.list();
    final todayKey = canonicalActionPlanDate(today);
    final habits = <MorningBriefingHabitSignal>[];
    for (final plan in plans.where(
      (plan) => plan.status == ActionPlanStatus.active,
    )) {
      for (final step in plan.steps) {
        if (step.frequency.isScheduled(today) &&
            step.completionHistory[todayKey] != true) {
          habits.add(
            MorningBriefingHabitSignal(
              stepId: step.id,
              title: step.title,
              targetNodeId: step.targetNodeId,
              currentRun: step.streakCount,
            ),
          );
        }
      }
    }
    habits.sort((left, right) => right.currentRun.compareTo(left.currentRun));

    double? sleepHours;
    double? restingHeartRate;
    final health = healthDataSource;
    if (health != null && (await isHealthEnabled?.call() ?? false)) {
      try {
        final sample = await health.readDay(yesterday);
        sleepHours = sample.sleepHours;
        restingHeartRate = sample.restingHeartRate;
      } on Object {
        // Health is optional; a missing permission or unavailable sample must
        // never prevent the local morning briefing.
      }
    }

    final previousVelocities = await store.clusterVelocities();
    final clusters = await clusterStore.list();
    final clusterSignals =
        [
          for (final cluster in clusters)
            MorningBriefingClusterSignal(
              clusterId: cluster.id,
              label: cluster.title,
              category: cluster.category.name,
              velocity: cluster.activityVelocity,
              velocityDelta:
                  cluster.activityVelocity -
                  (previousVelocities[cluster.id] ?? 0),
              nodeIds: cluster.nodeIds,
            ),
        ]..sort((left, right) {
          final delta = right.velocityDelta.compareTo(left.velocityDelta);
          return delta != 0 ? delta : right.velocity.compareTo(left.velocity);
        });

    return MorningBriefingPayload(
      localDay: today,
      timezoneOffsetMinutes: localNow.timeZoneOffset.inMinutes,
      journalEntryCount: entries.length,
      journalMinutes:
          entries.fold<int>(0, (sum, entry) => sum + entry.durationSeconds) ~/
          60,
      topicSignals: _topicSignals(entries.map((entry) => entry.transcript)),
      incompleteHabits: habits,
      clusterSignals: clusterSignals,
      sleepHours: sleepHours,
      restingHeartRate: restingHeartRate,
      museTriageCount: museTriageCount?.call() ?? 0,
    );
  }

  Future<bool> shouldPresent({DateTime? now}) async {
    final current = (now ?? _clock()).toLocal();
    final briefing = await store.forDay(current);
    if (briefing == null || await store.wasPresented(current)) return false;
    final snoozedUntil = await store.snoozedUntil();
    return snoozedUntil == null || !snoozedUntil.isAfter(current.toUtc());
  }

  Future<void> markPresented({DateTime? day}) =>
      store.markPresented((day ?? _clock()).toLocal());

  Future<void> snooze({Duration duration = const Duration(minutes: 30)}) =>
      store.snoozeUntil(_clock().toUtc().add(duration));

  Future<Uint8List?> audioFor(MorningBriefing briefing) =>
      audioStorage.read(briefing.id);
}

List<String> _topicSignals(Iterable<String> transcripts) {
  const stopWords = {
    'about',
    'after',
    'again',
    'also',
    'and',
    'because',
    'been',
    'but',
    'could',
    'from',
    'have',
    'just',
    'like',
    'really',
    'that',
    'the',
    'then',
    'there',
    'this',
    'today',
    'want',
    'was',
    'with',
    'would',
  };
  final counts = <String, int>{};
  for (final transcript in transcripts) {
    for (final match in RegExp(
      r"[a-zA-Z][a-zA-Z'-]{2,}",
    ).allMatches(transcript)) {
      final word = match.group(0)!.toLowerCase();
      if (!stopWords.contains(word)) counts[word] = (counts[word] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.toList()
    ..sort((left, right) {
      final count = right.value.compareTo(left.value);
      return count != 0 ? count : left.key.compareTo(right.key);
    });
  return ranked.take(10).map((entry) => entry.key).toList(growable: false);
}
