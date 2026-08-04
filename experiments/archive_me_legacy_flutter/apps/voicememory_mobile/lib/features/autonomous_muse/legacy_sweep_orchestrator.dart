import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:workmanager/workmanager.dart';

import '../data_ingestion/graph_ingestion_pipeline.dart';
import '../data_ingestion/legacy_ingestion_store.dart';
import '../neural_sculptor/lora_adapter_trainer.dart';
import '../../core/search/local_vector_search_engine.dart';
import 'autonomous_muse_models.dart';
import 'autonomous_muse_store.dart';
import 'semantic_bridge_builder.dart';
import 'thematic_triage.dart';

abstract interface class LegacySweepScheduler {
  Future<void> schedule();
}

abstract interface class LegacySweepBatchExecutor {
  Future<List<LegacySweepNote>> prepare(List<LegacySweepNote> notes);
}

/// Moves batch payload preparation off the UI isolate. Native Llama inference
/// has its own worker isolate; SQLite writes return to the owning isolate.
final class IsolatedLegacySweepBatchExecutor
    implements LegacySweepBatchExecutor {
  const IsolatedLegacySweepBatchExecutor();

  @override
  Future<List<LegacySweepNote>> prepare(List<LegacySweepNote> notes) =>
      Isolate.run(
        () => [
          for (final note in notes)
            LegacySweepNote(
              id: note.id,
              title: note.title,
              markdown: note.markdown,
              tags: note.tags,
            ),
        ],
      );
}

final class WorkmanagerLegacySweepScheduler implements LegacySweepScheduler {
  static const taskName = 'archiveMe.legacySweep.drain';
  static const uniqueName = 'com.voicememory.mobile.legacy.sweep';

  @override
  Future<void> schedule() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }
}

abstract interface class LegacySweepController {
  Stream<LegacySweepProgress> get progress;
  LegacySweepProgress get currentProgress;
  List<LegacyBridgeSuggestion> pendingSuggestions();
  List<ThematicDeck> thematicDecks({bool includeDeepConnections = false});
  int backlogCount({bool includeDeepConnections = false});
  Future<void> accept(String suggestionId);
  Future<void> reject(String suggestionId);
  Future<void> defer(String suggestionId);
}

final class LegacySweepOrchestrator
    implements LegacyPostImportSweepQueue, LegacySweepController {
  LegacySweepOrchestrator({
    required this.legacyStore,
    required this.museStore,
    required this.bridgeBuilder,
    required this.scheduler,
    this.batchExecutor = const IsolatedLegacySweepBatchExecutor(),
    DailyDigestQueue? dailyQueue,
    ThematicClusterManager? thematicClusterManager,
    NeuralHardwareProbe? hardwareProbe,
    Future<void> Function(Duration)? sleeper,
    DateTime Function()? clock,
    this.batchSize = 50,
    this.thermalPause = const Duration(minutes: 2),
    this.interBatchDelay = const Duration(seconds: 3),
  }) : assert(batchSize > 0 && batchSize <= 50),
       _hardwareProbe = hardwareProbe ?? PlatformNeuralHardwareProbe(),
       _sleeper = sleeper ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now,
       _dailyQueue =
           dailyQueue ?? DailyDigestQueue(store: museStore, clock: clock),
       _thematicClusterManager =
           thematicClusterManager ??
           const ThematicClusterManager(
             embeddingDriver: HashedLocalEmbeddingDriver(),
           );

  final LegacyIngestionStore legacyStore;
  final AutonomousMuseStore museStore;
  final LegacyBridgeBuilding bridgeBuilder;
  final LegacySweepScheduler scheduler;
  final LegacySweepBatchExecutor batchExecutor;
  final int batchSize;
  final Duration thermalPause;
  final Duration interBatchDelay;
  final NeuralHardwareProbe _hardwareProbe;
  final Future<void> Function(Duration) _sleeper;
  final DateTime Function() _clock;
  final DailyDigestQueue _dailyQueue;
  final ThematicClusterManager _thematicClusterManager;
  final StreamController<LegacySweepProgress> _progress =
      StreamController<LegacySweepProgress>.broadcast();
  bool _running = false;

  @override
  Stream<LegacySweepProgress> get progress => _progress.stream;

  @override
  LegacySweepProgress get currentProgress =>
      museStore.readLegacySweepProgress();

  @override
  List<LegacyBridgeSuggestion> pendingSuggestions() => _dailyQueue.active();

  @override
  List<ThematicDeck> thematicDecks({bool includeDeepConnections = false}) =>
      _thematicClusterManager.cluster(
        _dailyQueue.active(includeDeepConnections: includeDeepConnections),
      );

  @override
  int backlogCount({bool includeDeepConnections = false}) =>
      _dailyQueue.backlogCount(includeDeepConnections: includeDeepConnections);

  Future<void> schedulePending() async {
    if (legacyStore.undigestedNoteCount() > 0) {
      await scheduler.schedule();
    }
  }

  @override
  Future<void> enqueue(Iterable<String> noteIds) async {
    if (noteIds.isEmpty) return;
    final previous = currentProgress;
    final pending = legacyStore.undigestedNoteCount();
    final now = _clock().toUtc();
    _save(
      LegacySweepProgress(
        status: LegacySweepStatus.queued,
        totalNodes: previous.analyzedNodes + pending,
        analyzedNodes: previous.analyzedNodes,
        connectionsForged: previous.connectionsForged,
        startedAt: previous.startedAt ?? now,
        updatedAt: now,
      ),
    );
    await scheduler.schedule();
  }

  Future<void> drainBatch() async {
    if (_running) return;
    _running = true;
    try {
      final pendingNotes = legacyStore.readUndigestedNotes(limit: batchSize);
      final notes = await batchExecutor.prepare(pendingNotes);
      if (notes.isEmpty) {
        _save(_completed(currentProgress));
        return;
      }
      final hardware = await _hardwareProbe.current();
      if (hardware.thermalState == NeuralThermalState.serious ||
          hardware.thermalState == NeuralThermalState.critical) {
        final previous = currentProgress;
        _save(
          LegacySweepProgress(
            status: LegacySweepStatus.pausedThermal,
            totalNodes: previous.totalNodes,
            analyzedNodes: previous.analyzedNodes,
            connectionsForged: previous.connectionsForged,
            startedAt: previous.startedAt,
            updatedAt: _clock(),
          ),
        );
        await _sleeper(thermalPause);
        await scheduler.schedule();
        return;
      }

      var state = currentProgress;
      if (state.status == LegacySweepStatus.idle ||
          state.status == LegacySweepStatus.completed) {
        final now = _clock();
        state = LegacySweepProgress(
          status: LegacySweepStatus.running,
          totalNodes: legacyStore.undigestedNoteCount(),
          analyzedNodes: 0,
          connectionsForged: 0,
          startedAt: now,
          updatedAt: now,
        );
      } else {
        state = LegacySweepProgress(
          status: LegacySweepStatus.running,
          totalNodes: state.totalNodes,
          analyzedNodes: state.analyzedNodes,
          connectionsForged: state.connectionsForged,
          startedAt: state.startedAt,
          updatedAt: _clock(),
        );
      }
      _save(state);

      var forged = state.connectionsForged;
      var analyzed = state.analyzedNodes;
      for (final note in notes) {
        final suggestions = await bridgeBuilder.build(note);
        legacyStore.markDigested([note.id]);
        forged += suggestions.length;
        analyzed++;
        _save(
          LegacySweepProgress(
            status: LegacySweepStatus.running,
            totalNodes: state.totalNodes,
            analyzedNodes: analyzed,
            connectionsForged: forged,
            startedAt: state.startedAt,
            updatedAt: _clock(),
          ),
        );
      }
      if (legacyStore.undigestedNoteCount() == 0) {
        _save(_completed(currentProgress));
      } else {
        final current = currentProgress;
        _save(
          LegacySweepProgress(
            status: LegacySweepStatus.queued,
            totalNodes: current.totalNodes,
            analyzedNodes: current.analyzedNodes,
            connectionsForged: current.connectionsForged,
            startedAt: current.startedAt,
            updatedAt: _clock(),
          ),
        );
        await _sleeper(interBatchDelay);
        await scheduler.schedule();
      }
    } on Object catch (error) {
      final current = currentProgress;
      _save(
        LegacySweepProgress(
          status: LegacySweepStatus.failed,
          totalNodes: current.totalNodes,
          analyzedNodes: current.analyzedNodes,
          connectionsForged: current.connectionsForged,
          startedAt: current.startedAt,
          updatedAt: _clock(),
          error: '$error',
        ),
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  @override
  Future<void> accept(String suggestionId) async {
    await bridgeBuilder.accept(suggestionId);
    _emit(currentProgress);
  }

  @override
  Future<void> reject(String suggestionId) async {
    bridgeBuilder.reject(suggestionId);
    _emit(currentProgress);
  }

  @override
  Future<void> defer(String suggestionId) async {
    final now = _clock();
    bridgeBuilder.defer(
      suggestionId,
      DateTime(now.year, now.month, now.day + 1),
    );
    _emit(currentProgress);
  }

  LegacySweepProgress _completed(LegacySweepProgress current) =>
      LegacySweepProgress(
        status: LegacySweepStatus.completed,
        totalNodes: current.totalNodes,
        analyzedNodes: current.totalNodes,
        connectionsForged: current.connectionsForged,
        startedAt: current.startedAt,
        updatedAt: _clock(),
      );

  void _save(LegacySweepProgress value) {
    museStore.saveLegacySweepProgress(value);
    _emit(value);
  }

  void _emit(LegacySweepProgress value) {
    if (!_progress.isClosed) _progress.add(value);
  }

  Future<void> dispose() => _progress.close();
}
