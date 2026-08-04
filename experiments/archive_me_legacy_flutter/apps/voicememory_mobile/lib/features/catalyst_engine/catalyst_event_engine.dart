import 'dart:async';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

import 'catalyst_models.dart';
import 'catalyst_store.dart';

typedef CatalystRecipeExecutor =
    Future<CatalystRunLog> Function(
      CatalystRecipe recipe,
      CatalystEvent event, {
      bool dryRun,
    });

abstract interface class CatalystBackgroundScheduler {
  Future<void> schedule();
  Future<void> cancel();
}

final class WorkmanagerCatalystScheduler
    implements CatalystBackgroundScheduler {
  static const taskName = 'archiveMe.catalyst.tick';
  static const uniqueName = 'com.voicememory.mobile.catalyst.tick';

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> schedule() {
    if (!_supported) return Future.value();
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
    );
  }

  @override
  Future<void> cancel() => _supported
      ? Workmanager().cancelByUniqueName(uniqueName)
      : Future.value();
}

final class CatalystEventEngine {
  CatalystEventEngine({
    required this.store,
    required this.execute,
    required this.isForegroundUnlocked,
    this.scheduler,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CatalystStore store;
  final CatalystRecipeExecutor execute;
  final bool Function() isForegroundUnlocked;
  final CatalystBackgroundScheduler? scheduler;
  final DateTime Function() _clock;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _timer;
  bool _paused = false;
  bool _dispatching = false;
  final StreamController<CatalystEvent> _events = StreamController.broadcast();

  Stream<CatalystEvent> get events => _events.stream;

  Future<void> start({
    Stream<Object?>? journalChanges,
    Stream<Object?>? graphChanges,
    Stream<Object?>? transcriptionCompletions,
    Stream<Object?>? vaultCompletions,
  }) async {
    void subscribe(Stream<Object?>? stream, CatalystTriggerKind kind) {
      if (stream == null) return;
      _subscriptions.add(
        stream.listen((_) {
          unawaited(emit(kind, payload: const {'source': 'local_stream'}));
        }),
      );
    }

    subscribe(journalChanges, CatalystTriggerKind.journalChanged);
    subscribe(graphChanges, CatalystTriggerKind.graphChanged);
    subscribe(
      transcriptionCompletions,
      CatalystTriggerKind.transcriptionCompleted,
    );
    subscribe(vaultCompletions, CatalystTriggerKind.transcriptionCompleted);
    _timer ??= Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(emit(CatalystTriggerKind.scheduleTick)),
    );
    await scheduler?.schedule();
  }

  Future<void> firstUnlock() async {
    final now = _clock().toLocal();
    final day =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final state = await store.read();
    if (state.lastFirstUnlockDay == day) {
      await drainPending();
      return;
    }
    await store.update((current) => current.copyWith(lastFirstUnlockDay: day));
    await emit(CatalystTriggerKind.firstUnlock, payload: {'localDay': day});
    await drainPending();
  }

  Future<void> emit(
    CatalystTriggerKind kind, {
    Map<String, Object?> payload = const {},
    bool background = false,
    String? id,
  }) async {
    final occurredAt = _clock().toUtc();
    final event = CatalystEvent(
      id:
          id ??
          '${kind.name}:${occurredAt.microsecondsSinceEpoch}:'
              '${payload.hashCode}',
      kind: kind,
      occurredAt: occurredAt,
      payload: Map.unmodifiable(payload),
      background: background,
    );
    if (!_events.isClosed) _events.add(event);
    if (_paused || background || !isForegroundUnlocked()) {
      await store.queueEvent(event);
      return;
    }
    await _dispatch(event);
  }

  Future<void> _dispatch(CatalystEvent event) async {
    if (_dispatching) {
      await store.queueEvent(event);
      return;
    }
    _dispatching = true;
    try {
      final state = await store.read();
      if (state.processedEventIds.contains(event.id)) return;
      for (final recipe in state.recipes) {
        if (!recipe.enabled || recipe.trigger.kind != event.kind) continue;
        if (!_scheduleMatches(recipe, event, state.runs)) continue;
        final run = await execute(recipe, event, dryRun: false);
        await store.appendRun(run);
      }
      await store.update((current) {
        final processed = {...current.processedEventIds, event.id};
        final bounded = processed.length <= CatalystStore.maximumProcessedEvents
            ? processed
            : processed
                  .skip(processed.length - CatalystStore.maximumProcessedEvents)
                  .toSet();
        return current.copyWith(processedEventIds: bounded);
      });
    } finally {
      _dispatching = false;
    }
  }

  bool _scheduleMatches(
    CatalystRecipe recipe,
    CatalystEvent event,
    List<CatalystRunLog> runs,
  ) {
    if (event.kind != CatalystTriggerKind.scheduleTick) return true;
    final interval =
        (recipe.trigger.configuration['intervalHours'] as num?)?.toInt() ?? 1;
    final latest = runs
        .where((run) => run.recipeId == recipe.id)
        .map((run) => run.finishedAt)
        .fold<DateTime?>(null, (current, date) {
          if (current == null || date.isAfter(current)) return date;
          return current;
        });
    return latest == null ||
        event.occurredAt.difference(latest) >= Duration(hours: interval);
  }

  Future<void> drainPending() async {
    if (_paused || !isForegroundUnlocked()) return;
    final pending = (await store.read()).pendingEvents;
    await store.update(
      (state) => state.copyWith(pendingEvents: const <CatalystEvent>[]),
    );
    for (final event in pending) {
      await _dispatch(event);
    }
  }

  void pause() {
    _paused = true;
  }

  Future<void> resume() async {
    _paused = false;
    await drainPending();
  }

  Future<void> dispose() async {
    _paused = true;
    _timer?.cancel();
    _timer = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await scheduler?.cancel();
    await _events.close();
  }
}
