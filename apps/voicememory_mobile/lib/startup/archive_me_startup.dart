import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../config/app_config.dart';
import '../config/developer_settings_gate.dart';
import '../config/trial_mode.dart';
import '../features/activation/activation_tracker.dart';
import '../features/beta/beta_activation_loop_tracker.dart';
import '../features/objective/current_objective_widget_refresh_service.dart';
import '../features/proof_admission/archive_correction_store.dart';
import '../features/proof_admission/proof_scope_provider.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import '../features/live_audio/presentation/offline_vault_recovery_launch_controller.dart';
import '../router/onboarding_gate.dart';
import '../security/private_storage_audit.dart';
import '../services/app_services.dart';
import '../storage/app_storage_paths.dart';
import '../theme/app_colors.dart';

/// Completes startup work that touches local storage and platform services.
Future<void> completeArchiveMeStartup() async {
  await AppStoragePaths.configureFromDeviceInfo();
  await AppServices.initialize();
  ArchiveCorrectionStore.instance.configure(AppServices.instance.prefs);
  // A resumed signed-in session (see `AppServices.initialize`, which opens
  // that account's own namespace before this line ever runs) must load its
  // own corrections under its own archive scope, not silently under the
  // guest default `switchArchive`'s constructor seed leaves it at — this is
  // the same reconciliation `AppServices._switchToNamespace` performs on a
  // live account switch, just also needed once here for the namespace that
  // was already active before the very first `ensureLoaded` call.
  await ArchiveCorrectionStore.instance.switchArchive(
    const AppServicesProofScopeProvider().activeArchiveScope,
  );
  await ArchiveCorrectionStore.instance.ensureLoaded();
  await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();
  await OfflineVaultRecoveryLaunchController.prepareScan();
  unawaited(
    AppServices.instance.liveVoiceRecoveryGateway.checkForPendingRecovery(),
  );
  PrivateStorageAudit.logAuditReport();
  await CurrentObjectiveWidgetRefreshService.capturePendingLaunchRoute();
  await CheckInReminderService.ensureInitialized();
  await CuriosityNotificationLaunchController.ensureInitialized();
  unawaited(BetaActivationLoopTracker.trackAppOpened());
  if (TrialMode.enabled) {
    onboardingGate.markComplete();
    await ActivationTracker.trackTrialAppOpened();
  } else {
    await _loadDeveloperSettingsGate();
    await onboardingGate.refresh();
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

Future<void> _loadDeveloperSettingsGate() async {
  final unlocked = await AppServices.instance.prefs.readBool(
    DeveloperSettingsGate.prefsUnlockKey,
  );
  DeveloperSettingsGate.loadFromPrefs(unlocked);
}

/// Shows the first frame immediately, then runs [completeArchiveMeStartup].
class ArchiveMeBootstrapApp extends StatefulWidget {
  const ArchiveMeBootstrapApp({super.key});

  @override
  State<ArchiveMeBootstrapApp> createState() => _ArchiveMeBootstrapAppState();
}

class _ArchiveMeBootstrapAppState extends State<ArchiveMeBootstrapApp> {
  bool _ready = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterFirstFrame());
  }

  Future<void> _initAfterFirstFrame() async {
    try {
      await completeArchiveMeStartup();
    } catch (e, st) {
      debugPrint('ARCHIVEME_SIMULATOR_NATIVE_ASSETS: startup failed: $e');
      debugPrint('$st');
      _startupError = e;
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _startupError == null) {
      return const ArchiveMeApp();
    }
    if (_ready && _startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ArchiveMe could not start local storage on this simulator.\n'
                '$_startupError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SizedBox.shrink(),
      ),
    );
  }
}
