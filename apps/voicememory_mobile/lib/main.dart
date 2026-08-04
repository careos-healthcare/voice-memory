import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/force_screenshot_repeat_card.dart';
import 'features/performance/capture_performance_tracker.dart';
import 'startup/archive_me_startup.dart';
import 'storage/app_storage_paths.dart';
import 'theme/system_overlay_style_resolver.dart';

Future<void> main() async {
  // Earliest point Dart controls. Native pre-main time is not measurable here
  // and is excluded from the reported span.
  CapturePerformanceTracker.instance.markAppLaunch();
  WidgetsFlutterBinding.ensureInitialized();
  SystemOverlayStyleResolver.apply();
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
