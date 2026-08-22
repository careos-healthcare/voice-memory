import 'dart:async';

import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_store.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Orchestrates Loop Mode activation and progress tracking.
abstract class LoopModeCoordinator {
  LoopModeCoordinator._();

  static const _engine = LoopModeEngine();

  static Future<LoopMode?> loadActive() async {
    if (!AppServices.isInitialized) return null;
    return LoopModeStore.instance().load();
  }

  static Future<LoopMode> activate(String loopId) async {
    final mode = _engine.activate(loopId).copyWith(active: true);
    await LoopModeStore.instance().save(mode);
    ActivationTracker.trackLoopModeSelected();
    return mode;
  }

  static Future<LoopMode?> activateNotSure() async {
    return activate(LoopModeIds.notSure);
  }

  static Future<void> markFirstPromptUsed() async {
    final mode = await loadActive();
    if (mode == null) return;
    await LoopModeStore.instance().save(
      mode.copyWith(firstPromptUsed: true, updatedAt: DateTime.now()),
    );
    ActivationTracker.trackLoopFirstPromptUsed();
  }

  static Future<void> onRecordingSaved() async {
    final mode = await loadActive();
    if (mode == null) return;
    final count = mode.completedRecordingCount + 1;
    await LoopModeStore.instance().save(
      mode.copyWith(completedRecordingCount: count, updatedAt: DateTime.now()),
    );
    if (count == 1) {
      ActivationTracker.trackLoopFirstRecordingSaved();
    }
  }

  static Future<void> markReadAccepted() async {
    final mode = await loadActive();
    if (mode == null) return;
    await LoopModeStore.instance().save(
      mode.copyWith(readAccepted: true, updatedAt: DateTime.now()),
    );
    ActivationTracker.trackLoopReadAccepted();
    unawaited(AcquisitionCohortCoordinator.markFirstReadAccepted());
    if (mode.id == LoopModeIds.proveEnough) {
      ActivationTracker.trackProveReadAccepted();
    }
  }

  static Future<void> markUnsupportedRecording() async {
    final mode = await loadActive();
    if (mode == null) return;
    await LoopModeStore.instance().save(
      mode.copyWith(unsupportedRecording: true, updatedAt: DateTime.now()),
    );
    ActivationTracker.trackLoopUnsupportedRecording();
  }

  static Future<void> markReadRejected() async {
    final mode = await loadActive();
    if (mode == null) return;
    ActivationTracker.trackLoopReadRejected();
    unawaited(AcquisitionCohortCoordinator.markFirstReadRejected());
  }

  static Future<void> markCompleted() async {
    final mode = await loadActive();
    if (mode == null) return;
    await LoopModeStore.instance().save(
      mode.copyWith(completed: true, updatedAt: DateTime.now()),
    );
    ActivationTracker.trackLoopCompleted();
  }

  static Future<void> clearActive() async {
    if (!AppServices.isInitialized) return;
    await LoopModeStore.instance().clear();
  }

  static LoopModeEngine engine() => _engine;

  static Future<void> trackLoopModeSelectedMetric() async {
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.loopModeSelected,
    );
  }
}