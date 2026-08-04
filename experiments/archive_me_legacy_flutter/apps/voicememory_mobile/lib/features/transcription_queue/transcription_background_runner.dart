import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../services/app_services.dart';
import '../../storage/app_storage_paths.dart';
import '../connectors/healthkit_connector.dart';
import '../morning_briefing/morning_briefing_service.dart';
import '../autonomous_muse/autonomous_muse_service.dart';
import '../autonomous_muse/legacy_sweep_orchestrator.dart';
import '../catalyst_engine/catalyst_event_engine.dart';
import '../catalyst_engine/catalyst_models.dart';

abstract interface class TranscriptionWorkScheduler {
  Future<void> initialize();

  Future<void> schedule();
}

/// Focused V1 keeps durable transcription retries in the foreground and does
/// not register native background-processing tasks.
final class ForegroundOnlyTranscriptionScheduler
    implements TranscriptionWorkScheduler {
  const ForegroundOnlyTranscriptionScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule() async {}
}

typedef TranscriptionWorkerBootstrap = Future<void> Function();
typedef CatalystWorkerTick = Future<void> Function();
typedef LegacySweepWorkerDrain = Future<void> Function();

Future<bool> runTranscriptionBackgroundTask(
  String task, {
  TranscriptionWorkerBootstrap? bootstrap,
  CatalystWorkerTick? catalystTick,
  LegacySweepWorkerDrain? legacySweepDrain,
}) async {
  if (task == WorkmanagerLegacySweepScheduler.taskName ||
      task == WorkmanagerLegacySweepScheduler.uniqueName) {
    try {
      if (legacySweepDrain != null) {
        await legacySweepDrain();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
        await AppStoragePaths.configureFromDeviceInfo();
        await AppServices.initialize(backgroundWorker: true);
        await AppServices.instance.legacySweepOrchestrator?.drainBatch();
      }
      return true;
    } on Object {
      return false;
    }
  }
  if (task == WorkmanagerCatalystScheduler.taskName ||
      task == WorkmanagerCatalystScheduler.uniqueName) {
    try {
      if (catalystTick != null) {
        await catalystTick();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
        await AppStoragePaths.configureFromDeviceInfo();
        await AppServices.initialize(backgroundWorker: true);
        await AppServices.instance.catalystEventEngine?.emit(
          CatalystTriggerKind.scheduleTick,
          background: true,
        );
      }
      return true;
    } on Object {
      return false;
    }
  }
  if (task == WorkmanagerMorningBriefingScheduler.taskName ||
      task == WorkmanagerMorningBriefingScheduler.uniqueName) {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AppStoragePaths.configureFromDeviceInfo();
      await AppServices.initialize(backgroundWorker: true);
      final service = AppServices.instance.morningBriefingService;
      if (service == null) return true;
      await service.generateIfDue();
      await service.scheduleNext();
      return true;
    } on Object {
      return false;
    }
  }
  if (task == WorkmanagerHealthConnectorScheduler.taskName ||
      task == WorkmanagerHealthConnectorScheduler.uniqueName) {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AppStoragePaths.configureFromDeviceInfo();
      await AppServices.initialize(backgroundWorker: true);
      final connector = AppServices.instance.healthKitConnector;
      await connector?.restore();
      await connector?.syncNow();
      return true;
    } on Object {
      return false;
    }
  }
  if (task == WorkmanagerMuseScheduler.taskName ||
      task == WorkmanagerMuseScheduler.uniqueName) {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AppStoragePaths.configureFromDeviceInfo();
      await AppServices.initialize(backgroundWorker: true);
      await AppServices.instance.autonomousMuseService.runSweep();
      return true;
    } on Object {
      return false;
    }
  }
  if (task != WorkmanagerTranscriptionScheduler.taskName &&
      task != WorkmanagerTranscriptionScheduler.uniqueName) {
    return true;
  }
  try {
    if (bootstrap != null) {
      await bootstrap();
    } else {
      WidgetsFlutterBinding.ensureInitialized();
      await AppStoragePaths.configureFromDeviceInfo();
      await AppServices.initialize(backgroundWorker: true);
      await AppServices.instance.transcriptionQueueExecutor.drain(maxJobs: 2);
      await AppServices.instance.captureApiRetryQueue.drain();
    }
    return true;
  } on Object {
    return false;
  }
}

final class WorkmanagerTranscriptionScheduler
    implements TranscriptionWorkScheduler {
  static const taskName = 'archiveMe.transcriptionQueue.drain';
  static const uniqueName = 'com.voicememory.mobile.transcription.processing';

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    if (!_supported) return;
    await Workmanager().initialize(transcriptionQueueCallbackDispatcher);
  }

  @override
  Future<void> schedule() async {
    if (!_supported) return;
    await Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
    );
  }
}

@pragma('vm:entry-point')
void transcriptionQueueCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    // A false result asks the OS to retry; the durable ledger remains source
    // of truth if plugins are unavailable in the headless isolate.
    return runTranscriptionBackgroundTask(task);
  });
}
