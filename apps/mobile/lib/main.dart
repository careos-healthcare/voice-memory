import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/app.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/force_screenshot_repeat_card.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_workmanager.dart';
import 'package:archiveme_mobile/startup/archive_me_startup.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (V1CapabilityRegistry.backgroundProcessing &&
      WeeklySynthesisWorkScheduler.isSupported) {
    await WeeklySynthesisWorkScheduler.initialize();
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