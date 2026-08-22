import 'dart:async';

import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart' show V1ProductionAllowlist;
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/billing/application/billing_startup_provider.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/offline_vault_recovery_launch_controller.dart';
import 'package:archiveme_mobile/features/objective/current_objective_widget_refresh_service.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_service.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_service.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_bootstrap.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_routine_launch_controller.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import 'package:archiveme_mobile/features/watch/watch_session_coordinator.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/security/private_storage_audit.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:flutter/services.dart';

/// Staged V1 startup aligned with [V1ProductionAllowlist.startupPhases].
abstract final class V1StartupCoordinator {
  V1StartupCoordinator._();

  /// Phases 2–3: local archive, corrections, onboarding — blocks first navigation.
  static Future<void> runEssentialPhases() async {
    await AppStoragePaths.configureFromDeviceInfo();
    await AppServices.initializeEssential();
    await reconcileArchiveCorrectionStoreForActiveNamespace(
      AppServices.instance.prefs,
      migrateLegacyFeedback: true,
    );
    if (TrialMode.enabled) {
      onboardingGate.markComplete();
      await ActivationTracker.trackTrialAppOpened();
    } else {
      await _loadDeveloperSettingsGate();
      await onboardingGate.refresh();
    }
  }

  /// Phase 4: billing, sync helpers, vault recovery — best-effort background.
  static Future<void> runOptionalPhases() async {
    await AppServices.initializeOptionalServices();
    if (!TrialMode.enabled) {
      await appProviderContainer.read(billingInitializationProvider.future);
    }
    if (V1CapabilityRegistry.liveVoice) {
      await OfflineVaultRecoveryLaunchController.prepareScan();
      unawaited(
        AppServices.instance.liveVoiceRecoveryGateway.checkForPendingRecovery(),
      );
    }
    if (V1CapabilityRegistry.watchCompanion && AppServices.isInitialized) {
      final connectivity = AppServices.instance.watchConnectivity;
      if (connectivity != null) {
        final coordinator = WatchSessionCoordinator(connectivity: connectivity);
        await coordinator.initialize();
      }
    }
    if (V1CapabilityRegistry.nativeExtensions) {
      await CurrentObjectiveWidgetRefreshService.capturePendingLaunchRoute();
    }
    if (AppServices.isInitialized && V1CapabilityRegistry.nativeExtensions) {
      unawaited(QuickCaptureWidgetService.runStartupTasks());
      unawaited(
        AppServices.instance.trendAnalysisService.then(
          (service) => service.scheduleRefresh(),
        ),
      );
    }
    if (V1CapabilityRegistry.notifications) {
      await CheckInReminderService.ensureInitialized();
      await CaptureRoutineLaunchController.ensureInitialized();
      await CuriosityNotificationLaunchController.ensureInitialized();
    }
    unawaited(BetaActivationLoopTracker.trackAppOpened());
    PrivateStorageAudit.logAuditReport();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static Future<void> _loadDeveloperSettingsGate() async {
    final unlocked = await AppServices.instance.prefs.readBool(
      DeveloperSettingsGate.prefsUnlockKey,
    );
    DeveloperSettingsGate.loadFromPrefs(unlocked);
  }
}