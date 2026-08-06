import 'dart:async';

import 'package:flutter/services.dart';

import '../config/developer_settings_gate.dart';
import '../config/trial_mode.dart';
import '../core/config/v1_capability_registry.dart';
import '../core/config/v1_feature_flags.dart';
import '../features/activation/activation_tracker.dart';
import '../features/beta/beta_activation_loop_tracker.dart';
import '../features/live_audio/presentation/offline_vault_recovery_launch_controller.dart';
import '../features/objective/current_objective_widget_refresh_service.dart';
import '../features/proof_admission/archive_correction_bootstrap.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import '../router/onboarding_gate.dart';
import '../security/private_storage_audit.dart';
import '../services/app_services.dart';
import '../storage/app_storage_paths.dart';

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
    if (V1CapabilityRegistry.liveVoice) {
      await OfflineVaultRecoveryLaunchController.prepareScan();
      unawaited(
        AppServices.instance.liveVoiceRecoveryGateway
            .checkForPendingRecovery(),
      );
    }
    if (!V1FeatureFlags.enableV1Only) {
      await CurrentObjectiveWidgetRefreshService.capturePendingLaunchRoute();
      await CheckInReminderService.ensureInitialized();
      await CuriosityNotificationLaunchController.ensureInitialized();
      unawaited(BetaActivationLoopTracker.trackAppOpened());
    }
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
