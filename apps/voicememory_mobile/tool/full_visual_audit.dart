import 'dart:convert';
import 'dart:io';

import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/dev/visual_audit_registry.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';

/// Seeds journal + prefs for visual audit captures (integration test only).
class VisualAuditFixtures {
  VisualAuditFixtures._();

  static const List<int> archiveRecordingCounts = [0, 1, 2, 3, 4, 5, 10];

  static Future<void> prepareApp() async {
    await AppConfig.initApiResolution();
    await AppServices.initialize();
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
  }

  static Future<void> clearJournal() async {
    final store = AppServices.instance.journalStore;
    final all = await store.loadAll();
    for (final e in all) {
      await store.delete(e.id);
    }
  }

  static Future<void> seedRecordingCount(int count) async {
    await clearJournal();
    if (count <= 0) return;
    final store = AppServices.instance.journalStore;
    final themes = ['career', 'relationships', 'health', 'purpose', 'family'];
    for (var i = 0; i < count; i++) {
      final theme = themes[i % themes.length];
      await store.save(
        JournalEntry(
          id: 'audit-entry-$i',
          createdAt: DateTime.utc(2026, 3, 1 + i, 10, i),
          transcript:
              'Visual audit sample $i: I keep thinking about $theme and what it means '
              'for my next steps. I am not sure yet but I want more clarity over time.',
          durationSeconds: 30 + i,
          reflection: Reflection(
            mood: 'thoughtful',
            emotionalIntensity: 3 + (i % 3),
            recurringThemes: [theme],
            exactLanguagePattern: 'thinking about $theme',
            concreteObservation:
                'Theme $theme appeared again in reflection $i.',
            repeatedSignal: theme,
          ),
          syncStatus: i.isEven ? SyncStatus.synced : SyncStatus.localOnly,
        ),
      );
    }
  }

  /// Archive mode label for a given seeded count.
  static String archiveModeLabel(int count) {
    if (count == 0) return 'empty';
    if (count == 1) return 'first_reflection';
    if (count == 2) return 'comparison';
    if (count == 3) return 'pattern';
    if (count == 4) return 'momentum';
    if (count < AppConfig.patternReviewReflectionTarget)
      return 'progress_$count';
    return 'full';
  }

  static void setRecordIdle() {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(ui: RecordUiState.ready),
    );
  }

  static void setRecordRecording() {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(
        ui: RecordUiState.recording,
        stageLabel: 'Recording…',
      ),
    );
  }

  static void setRecordSaving() {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(
        ui: RecordUiState.processing,
        stageLabel: 'Saving…',
      ),
    );
  }

  static void setRecordLocalSaveSuccess() {
    VisualAuditOverrides.setRecordPresentation(
      RecordAuditPresentation(
        ui: RecordUiState.done,
        localSaveTitle: CaptureSaveMessages.recordingSavedLocally,
        syncNote:
            'Saved locally. Cloud sync will be available when backend sync is connected.',
        stageLabel: CaptureSaveMessages.recordingSavedLocally,
      ),
    );
  }

  static void setRecordSyncSuccess() {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(
        ui: RecordUiState.done,
        stageLabel: 'Saved',
      ),
    );
  }

  static void setRecordSyncUnavailable() {
    VisualAuditOverrides.setRecordPresentation(
      RecordAuditPresentation(
        ui: RecordUiState.done,
        localSaveTitle: CaptureSaveMessages.recordingSavedLocally,
        syncNote: ConsumerUiCopy.savedPrivatelyOnDevice,
        stageLabel: CaptureSaveMessages.recordingSavedLocally,
      ),
    );
  }

  static void setRecordMicrophoneDenied() {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(
        ui: RecordUiState.permissionBlocked,
        error: 'Microphone access is required to record.',
      ),
    );
  }

  static void clearRecordOverride() {
    VisualAuditOverrides.setRecordPresentation(null);
  }
}

/// JSON + markdown audit output.
class VisualAuditReport {
  VisualAuditReport({required this.outputRoot, required this.timestamp})
    : routesVisited = [],
      screenshots = [],
      errors = [],
      warnings = [],
      missingRoutes = [];

  final String outputRoot;
  final DateTime timestamp;
  final List<String> routesVisited;
  final List<Map<String, String>> screenshots;
  final List<Map<String, String>> errors;
  final List<String> warnings;
  final List<String> missingRoutes;

  int get totalScreenshots => screenshots.length;

  void addScreenshot({
    required String path,
    required String filename,
    required String folder,
    String? route,
    String? captureId,
  }) {
    screenshots.add({
      'path': path,
      'filename': filename,
      'folder': folder,
      if (route != null) 'route': route,
      if (captureId != null) 'id': captureId,
    });
  }

  void addError({
    required String message,
    String? route,
    String? captureId,
    String? screenshotPath,
  }) {
    errors.add({
      'message': message,
      if (route != null) 'route': route,
      if (captureId != null) 'id': captureId,
      if (screenshotPath != null) 'screenshot': screenshotPath,
      'at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> writeToDisk() async {
    final auditDir =
        '$outputRoot${Platform.pathSeparator}${VisualAuditFolders.audit}';
    await Directory(auditDir).create(recursive: true);

    final jsonPath = '$auditDir${Platform.pathSeparator}report.json';
    final payload = {
      'routesVisited': routesVisited,
      'screenshots': screenshots,
      'errors': errors,
      'warnings': warnings,
      'missingRoutes': missingRoutes,
      'timestamp': timestamp.toIso8601String(),
      'totalScreenshots': totalScreenshots,
      'outputRoot': outputRoot,
    };
    await File(
      jsonPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    final md = StringBuffer()
      ..writeln('# ArchiveMe Visual Audit Report')
      ..writeln()
      ..writeln('**Generated:** ${timestamp.toIso8601String()}')
      ..writeln('**Output:** `$outputRoot`')
      ..writeln()
      ..writeln('## Summary')
      ..writeln('- Total routes visited: ${routesVisited.length}')
      ..writeln('- Total screenshots: $totalScreenshots')
      ..writeln('- Screens with errors: ${errors.length}')
      ..writeln('- Warnings: ${warnings.length}')
      ..writeln('- Missing routes: ${missingRoutes.length}')
      ..writeln();

    if (errors.isNotEmpty) {
      md.writeln('## Errors');
      for (final e in errors) {
        md.writeln('- ${e['message']} (${e['route'] ?? e['id'] ?? 'unknown'})');
      }
      md.writeln();
    }

    if (warnings.isNotEmpty) {
      md.writeln('## Warnings');
      for (final w in warnings) {
        md.writeln('- $w');
      }
      md.writeln();
    }

    if (missingRoutes.isNotEmpty) {
      md.writeln('## Missing routes');
      for (final r in missingRoutes) {
        md.writeln('- $r');
      }
      md.writeln();
    }

    md.writeln('## Failed captures');
    final failed = errors.where((e) => e['screenshot'] != null).toList();
    if (failed.isEmpty) {
      md.writeln('_None_');
    } else {
      for (final e in failed) {
        md.writeln('- ${e['screenshot']}');
      }
    }

    await File(
      '$auditDir${Platform.pathSeparator}report.md',
    ).writeAsString(md.toString());

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('Visual audit complete');
    // ignore: avoid_print
    print('Output: $outputRoot');
    // ignore: avoid_print
    print('Total screenshots: $totalScreenshots');
    // ignore: avoid_print
    print('Routes visited: ${routesVisited.length}');
    // ignore: avoid_print
    print('Report: $auditDir/report.json');
  }
}
