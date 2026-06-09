import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/developer_settings_gate.dart';
import 'config/trial_mode.dart';
import 'router/onboarding_gate.dart';
import 'features/activation/activation_tracker.dart';
import 'features/objective/current_objective_widget_refresh_service.dart';
import 'features/tomorrow_return/check_in_reminder_service.dart';
import 'services/app_services.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await AppConfig.initApiResolution();
  await AppServices.initialize();
  await CurrentObjectiveWidgetRefreshService.capturePendingLaunchRoute();
  // Prepare the reminder backend (no permission prompt happens here).
  await CheckInReminderService.ensureInitialized();
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
  runApp(const ArchiveMeApp());
}

Future<void> _loadDeveloperSettingsGate() async {
  final unlocked = await AppServices.instance.prefs.readBool(
    DeveloperSettingsGate.prefsUnlockKey,
  );
  DeveloperSettingsGate.loadFromPrefs(unlocked);
}
