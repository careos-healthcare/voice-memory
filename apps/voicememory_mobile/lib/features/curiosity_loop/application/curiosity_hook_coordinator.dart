import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/journal_entry.dart';
import '../../../services/app_services.dart';
import '../../voice_capture/voice_capture_quality.dart';
import '../domain/services/curiosity_prompt_generator.dart';
import '../models/curiosity_hook.dart';
import '../repositories/curiosity_hook_repository.dart';
import 'curiosity_hook_journal_store.dart';
import '../services/curiosity_adaptive_timing_engine.dart';
import '../services/curiosity_hook_engine.dart';
import '../services/curiosity_hook_metadata_extractor.dart';
import '../services/curiosity_memory_recall_hook_enricher.dart';
import '../services/curiosity_notification_scheduler.dart';
import '../services/curiosity_telemetry_tracker.dart';

/// Post-save voice pipeline entry point for curiosity hooks.
class CuriosityHookCoordinator {
  CuriosityHookCoordinator({
    required CuriosityNotificationScheduler scheduler,
    CuriosityHookRepository? repository,
    CuriosityHookJournalStore? journalStore,
    CuriosityPromptGenerator? promptGenerator,
    CuriosityAdaptiveTimingEngine? timingEngine,
    CuriosityTelemetryTracker? telemetry,
    CuriosityMemoryRecallHookEnricher? memoryRecallEnricher,
  })  : _scheduler = scheduler,
        _repository = repository ?? LocalCuriosityHookRepository.instance(),
        _journalStore = journalStore ?? _defaultJournalStore(),
        _promptGenerator =
            promptGenerator ?? const DefaultCuriosityPromptGenerator(),
        _timingEngine = timingEngine ?? const CuriosityAdaptiveTimingEngine(),
        _telemetry = telemetry ?? const CuriosityTelemetryTracker(),
        _memoryRecallEnricher =
            memoryRecallEnricher ?? CuriosityMemoryRecallHookEnricher();

  static CuriosityHookCoordinator? _shared;

  static CuriosityHookCoordinator instance() =>
      _shared ??= CuriosityHookCoordinator(
        scheduler: CuriosityNotificationScheduler.instance(),
      );

  static CuriosityHookJournalStore _defaultJournalStore() =>
      JournalStoreCuriosityHookJournalStore(AppServices.instance.journalStore);

  final CuriosityNotificationScheduler _scheduler;
  final CuriosityHookRepository _repository;
  final CuriosityHookJournalStore _journalStore;
  final CuriosityPromptGenerator _promptGenerator;
  final CuriosityAdaptiveTimingEngine _timingEngine;
  final CuriosityTelemetryTracker _telemetry;
  final CuriosityMemoryRecallHookEnricher _memoryRecallEnricher;

  /// Persists a curiosity hook after voice save and schedules a return reminder.
  ///
  /// Notification scheduling never throws and never blocks the returned hook.
  Future<CuriosityHook?> persistAfterVoiceSave({
    required JournalEntry savedEntry,
    required List<JournalEntry> allEntries,
    CuriosityHookRepository? repository,
  }) async {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry)) return null;
    if (!VoiceCaptureQuality.hasUsableSpokenText(savedEntry)) return null;

    final repo = repository ?? _repository;
    await LocalCuriosityHookRepository.ensureLoaded();

    final metadata = CuriosityHookMetadataExtractor.fromEntry(
      entry: savedEntry,
      allEntries: allEntries,
    );
    final hook = CuriosityHookEngine.build(
      metadata: metadata,
      recentHookTypes: await repo.recentHookTypes(),
    );
    if (hook == null) return null;

    final recallHook = await _memoryRecallEnricher.applyPendingSeed(hook);
    final synthesizedHook = await _applySynthesizedPrompt(recallHook);

    await repo.saveHook(synthesizedHook);
    unawaited(
      _scheduleNotificationSafely(
        hook: synthesizedHook,
        history: allEntries,
        currentEntryTime: savedEntry.createdAt,
      ),
    );
    return synthesizedHook;
  }

  Future<CuriosityHook> _applySynthesizedPrompt(CuriosityHook hook) async {
    JournalEntry? sourceEntry;
    final sourceEntryId = hook.sourceEntryId?.trim();
    if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
      sourceEntry = await _journalStore.getEntryById(sourceEntryId);
    } else {
      sourceEntry = await _journalStore.getEntryById(hook.entryId);
    }

    final dynamicPrompt = await _promptGenerator.generatePrompt(
      hook: hook,
      sourceEntry: sourceEntry,
    );

    final trimmed = dynamicPrompt.trim();
    if (trimmed.isEmpty || trimmed == hook.dynamicPrompt) {
      return hook;
    }
    return hook.copyWith(dynamicPrompt: trimmed);
  }

  Future<void> markConsumed(
    String hookId, {
    CuriosityHookRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    await repo.markConsumed(hookId);
  }

  Future<void> _scheduleNotificationSafely({
    required CuriosityHook hook,
    required List<JournalEntry> history,
    required DateTime currentEntryTime,
  }) async {
    try {
      await _scheduler.initialize();
      if (!_scheduler.isAvailable) return;

      final granted = await _scheduler.requestPermissions();
      if (!granted) return;

      final scheduleAfter = _timingEngine.calculateOptimalDelay(
        history: history,
        currentEntryTime: currentEntryTime,
      );
      final scheduled = await _scheduler.scheduleCuriosityNotification(
        hook,
        scheduleAfter: scheduleAfter,
        promptBody: hook.dynamicPrompt,
      );
      if (scheduled) {
        _telemetry.trackHookScheduled(
          hookId: hook.id,
          hookType: hook.hookType.name,
          scheduleAfter: scheduleAfter,
        );
      }
    } catch (_) {
      // Notification failures must never disrupt the voice save loop.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _shared = null;
  }
}
