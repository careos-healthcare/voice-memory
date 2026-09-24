import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/app.dart';
import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/features/ambient_capture/home_screen_shortcuts.dart';
import 'package:archiveme_mobile/features/ambient_capture/record_widget_launch.dart';
import 'package:archiveme_mobile/features/ambient_capture/shortcut_record_launch.dart';
import 'package:archiveme_mobile/desktop/desktop_window_host.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/force_screenshot_repeat_card.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_background_entry.dart';
import 'package:archiveme_mobile/features/memos/life_memo_background.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_workmanager.dart';
import 'package:archiveme_mobile/startup/archive_me_startup.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShortcutRecordLaunch.beginBeforeUi();
  await bindAmbientCaptureEntryPoints();
  await QuickCaptureHomeWidgetRegistrar.register();
  await QuickCaptureHomeWidgetRegistrar.writeDesktopShortcutIfPresent(
    Platform.executableArguments,
  );
  await DesktopWindowHost.initialize();
  if (V1CapabilityRegistry.backgroundProcessing &&
      WeeklySynthesisWorkScheduler.isSupported) {
    await WeeklySynthesisWorkScheduler.initialize();
    await LifeMemoWorkScheduler.registerSundayTask();
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await AppConfig.initApiResolution();
  if (ForceScreenshotRepeatCard.enabled) {
    AppLogger.debug('FORCE_SCREENSHOT_REPEAT_CARD enabled');
  }

  if (await AppStoragePaths.shouldDeferLocalStorageUntilFirstFrame()) {
    runApp(const ArchiveMeBootstrapApp());
    return;
  }

  await completeArchiveMeStartup();
  runApp(const ArchiveMeApp());
}

/// Icon shortcuts and the record widget open the existing capture routes.
///
/// `New Voice Entry` lands on the recording screen. `Quick Text` lands on
/// typed capture. A widget tap uses the same recording route. If the navigator
/// is not up yet, [AmbientCaptureRouter] keeps the location until the shell
/// mounts.
Future<void> bindAmbientCaptureEntryPoints() async {
  await HomeScreenShortcuts.register();
  await RecordWidgetLaunch.bind();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AmbientCaptureRouter.flush();
  });
}
