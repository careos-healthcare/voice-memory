import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_headless_database.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_headless_writer.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_home_widget_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

/// Background isolate entry for home-widget and desktop shortcut submissions.
///
/// Initializes the encrypted SQLite connection only. It does not build a widget
/// tree, schedule sqlite-vec, or start embedding / LLM workers.
@pragma('vm:entry-point')
Future<void> quickCaptureBackgroundMain(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final text =
      QuickCaptureHomeWidgetConfig.textFromUri(uri) ?? await _savedWidgetText();
  if (text == null) return;

  final session = await QuickCaptureHeadlessDatabase.open();
  if (session == null) return;
  try {
    await QuickCaptureHeadlessWriter.writeText(
      database: session.sqlite.database,
      snippetFile: session.snippetFile,
      text: text,
    );
  } on Object catch (error, stackTrace) {
    AppLogger.debug(
      'Quick capture background write skipped',
      error: error,
      stackTrace: stackTrace,
    );
  } finally {
    await session.close();
  }
}

Future<String?> _savedWidgetText() async {
  if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    final saved = await HomeWidget.getWidgetData<String>(
      QuickCaptureHomeWidgetConfig.widgetTextKey,
    );
    final text = saved?.trim() ?? '';
    return text.isEmpty ? null : text;
  } on Object {
    return null;
  }
}

/// Registers the interactive widget callback on Android, iOS, and desktop.
abstract final class QuickCaptureHomeWidgetRegistrar {
  QuickCaptureHomeWidgetRegistrar._();

  static Future<void> register() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await HomeWidget.setAppGroupId(QuickCaptureHomeWidgetConfig.appGroupId);
      await HomeWidget.registerInteractivityCallback(
        quickCaptureBackgroundMain,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Quick capture widget registration skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handles a desktop shortcut before the UI shell starts.
  static Future<void> writeDesktopShortcutIfPresent(List<String> args) async {
    final text = QuickCaptureHomeWidgetConfig.textFromDesktopArguments(args);
    if (text == null) return;
    await quickCaptureBackgroundMain(
      QuickCaptureHomeWidgetConfig.uriForText(text),
    );
  }
}
