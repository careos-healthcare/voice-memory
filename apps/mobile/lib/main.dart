import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/app.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/force_screenshot_repeat_card.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/core/notifications/journal_reminder_slots.dart';
import 'package:archiveme_mobile/features/import/views/import_receipt_view.dart';
import 'package:archiveme_mobile/features/import/voice_memo_importer.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_workmanager.dart';
import 'package:archiveme_mobile/startup/archive_me_startup.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName =
      (await FlutterTimezone.getLocalTimezone()).identifier;
  tz.setLocalLocation(tz.getLocation(timeZoneName));
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
    runApp(
      const GentleRemindersLifecycleHost(child: ThoughtprintBootstrapApp()),
    );
    return;
  }

  try {
    await completeThoughtprintStartup();
  } on DatabaseDecryptionFailed {
    runApp(const ThoughtprintBackupRestoreApp());
    return;
  }
  await GentleRemindersService().rescheduleReminders();
  runApp(const GentleRemindersLifecycleHost(child: ThoughtprintApp()));
}

/// Refreshes local reminders when the app opens and whenever it returns
/// to the foreground.
class GentleRemindersLifecycleHost extends StatefulWidget {
  const GentleRemindersLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  State<GentleRemindersLifecycleHost> createState() =>
      _GentleRemindersLifecycleHostState();
}

class _GentleRemindersLifecycleHostState
    extends State<GentleRemindersLifecycleHost>
    with WidgetsBindingObserver {
  String? _zone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncZone());
    unawaited(GentleRemindersService().rescheduleReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncZone());
      unawaited(_importPendingVoiceMemo());
    }
  }

  Future<void> _syncZone() async {
    final next = (await FlutterTimezone.getLocalTimezone()).identifier;
    final changed = journalRemindersNeedReschedule(
      previousZone: _zone,
      nextZone: next,
    );
    _zone = next;
    tz.setLocalLocation(tz.getLocation(next));
    if (changed) {
      await GentleRemindersService().rescheduleReminders();
    }
  }

  Future<void> _importPendingVoiceMemo() async {
    if (!V1CapabilityRegistry.voiceMemosImport) return;
    if (!AppServices.isInitialized) return;
    final entry = await VoiceMemoImportInbox.transcribePending(
      readLocale: () => SpeechLocaleStore(AppServices.instance.prefs).read(),
    );
    if (entry == null) return;
    await presentVoiceMemoReceipt(
      entry: entry,
      save: (row) => AppServices.instance.journalStore.save(
        row,
        captureKind: 'voice',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}