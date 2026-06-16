import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/force_screenshot_repeat_card.dart';
import 'startup/archive_me_startup.dart';
import 'storage/app_storage_paths.dart';
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
  if (ForceScreenshotRepeatCard.enabled) {
    debugPrint('FORCE_SCREENSHOT_REPEAT_CARD enabled');
  }

  if (await AppStoragePaths.shouldDeferLocalStorageUntilFirstFrame()) {
    runApp(const ArchiveMeBootstrapApp());
    return;
  }

  await completeArchiveMeStartup();
  runApp(const ArchiveMeApp());
}
