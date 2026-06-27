import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/empty_states/search_empty_state.dart';

import '../tool/full_visual_audit.dart';

/// Production UI verification — screenshots under tool/screenshots/production_verify/
/// (or app temp dir when running on device/simulator).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Directory? outDir;

  Future<Directory> screenshotDir() async {
    if (outDir != null) return outDir!;
    final projectDir = Directory('tool/screenshots/production_verify');
    try {
      if (!projectDir.existsSync()) {
        projectDir.createSync(recursive: true);
      }
      final probe = File('${projectDir.path}${Platform.pathSeparator}.write_probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      outDir = projectDir;
      return outDir!;
    } on FileSystemException {
      outDir = Directory(
        '${(await getTemporaryDirectory()).path}/production_verify',
      );
      if (!outDir!.existsSync()) outDir!.createSync(recursive: true);
      return outDir!;
    }
  }

  Future<void> snap(WidgetTester tester, String filename) async {
    if (!kIsWeb && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final name = filename.replaceAll('.png', '');
    final bytes = await binding.takeScreenshot(name);
    final dir = await screenshotDir();
    final path = '${dir.path}${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    debugPrint('Saved $path');
  }

  Future<void> go(WidgetTester tester, String route) async {
    appRouter.go(route);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> waitForRecordFirstUse(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const Key('record_first_use_capture_section'))
          .evaluate()
          .isNotEmpty) {
        return;
      }
    }
  }

  Future<void> waitForPatternsMindMapEmpty(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const Key('patterns_empty_archive_preview_card'))
          .evaluate()
          .isNotEmpty) {
        return;
      }
    }
  }

  Future<void> waitForPatternsEmptyPreview(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const Key('patterns_empty_archive_preview_card'))
          .evaluate()
          .isNotEmpty) {
        return;
      }
    }
  }

  testWidgets('production UI verify + screenshots', (tester) async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = true;

    await VisualAuditFixtures.prepareApp();
    await AppServices.instance.prefs.writeBool(
      DeveloperSettingsGate.prefsUnlockKey,
      false,
    );
    DeveloperSettingsGate.loadFromPrefs(false);

    await tester.pumpWidget(const ArchiveMeApp());
    await tester.pump(const Duration(seconds: 1));

    // 1. Account shell + Settings — production only
    await go(tester, '/account');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Account'), findsWidgets);
    expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);

    await go(tester, '/settings');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(ConsumerUiCopy.settings), findsOneWidget);
    expect(find.text(ConsumerUiCopy.privacy), findsOneWidget);
    expect(find.text(ConsumerUiCopy.termsOfUse), findsOneWidget);
    expect(find.byKey(const Key('settings_support_feedback_tile')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(ConsumerUiCopy.deleteAccount),
      120,
    );
    expect(find.text(ConsumerUiCopy.deleteAccount), findsOneWidget);
    expect(find.text('Developer'), findsNothing);
    expect(find.text('RevenueCat verification'), findsNothing);
    expect(find.text('API base URL'), findsNothing);
    await snap(tester, 'settings_production_after.png');

    // 2. About + 7-tap unlock
    await go(tester, '/about');
    expect(find.text('Version'), findsOneWidget);
    await snap(tester, 'about_archive_me.png');
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Version'));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Advanced settings unlocked'), findsOneWidget);

    // 3. Empty states (cleared journal)
    await VisualAuditFixtures.clearJournal();

    await go(tester, '/archive-belief');
    await waitForPatternsMindMapEmpty(tester);
    expect(
      find.byKey(const Key('patterns_empty_archive_preview_card')),
      findsOneWidget,
    );
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
    expect(find.text('Type instead'), findsOneWidget);
    expect(find.text('Start your first week'), findsNothing);
    await snap(tester, 'archive_empty_state.png');

    await go(tester, '/discover-yourself');
    await waitForPatternsEmptyPreview(tester);
    expect(
      find.byKey(const Key('patterns_empty_archive_preview_card')),
      findsOneWidget,
    );
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
    await snap(tester, 'discover_empty_state.png');

    await go(tester, '/timeline');
    // Legacy route redirects to the Patterns tab (archive-belief).
    await waitForPatternsMindMapEmpty(tester);
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
    await snap(tester, 'timeline_empty_state.png');

    await go(tester, '/search');
    // Legacy route redirects to the Patterns tab (archive-belief).
    await waitForPatternsMindMapEmpty(tester);
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
    expect(find.text(SearchEmptyCopy.title), findsNothing);
    await snap(tester, 'search_empty_state.png');

    await go(tester, '/journal');
    await waitForPatternsEmptyPreview(tester);
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );

    // 4. Record — simplified first-use layout (empty archive)
    VisualAuditFixtures.setRecordIdle();
    await go(tester, '/record');
    await waitForRecordFirstUse(tester);

    expect(find.byKey(const Key('record_top_archive_promise_hero')), findsOneWidget);
    expect(find.text(VisibleArchiveProofCopy.recordHeroTitle), findsOneWidget);
    expect(find.byKey(const Key('record_first_use_capture_section')), findsOneWidget);
    expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    expect(find.byType(CaptureEntryActions), findsOneWidget);

    final primaryLabelVisible =
        find.text(VisibleArchiveProofCopy.firstUseCaptureCta).evaluate().isNotEmpty ||
        find.text(MicrophonePermissionCopy.allowMicrophoneCta).evaluate().isNotEmpty ||
        find.text(MicrophonePermissionCopy.openSettingsCta).evaluate().isNotEmpty;
    expect(primaryLabelVisible, isTrue);

    expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
    expect(find.byKey(const Key('capture_how_it_works_link')), findsOneWidget);
    expect(find.text(RecordScreenFramingCopy.firstRunPrivacyLink), findsOneWidget);

    expect(find.text(DailyArchiveExerciseCopy.recordLabel), findsOneWidget);
    expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsOneWidget);
    expect(find.textContaining('private mind map'), findsOneWidget);
    expect(find.text("Today's exercise"), findsNothing);
    expect(find.text(TodaysQuestionCopy.eyebrow), findsNothing);
    expect(find.byKey(const Key('todays_one_question_card')), findsNothing);
    expect(find.text(TodaysQuestionCopy.saveMomentCta), findsNothing);
    expect(find.text(CaptureEntryActions.logPressureMomentLabel), findsNothing);

    expect(find.text(RecordScreenFramingCopy.title), findsNothing);
    expect(find.text('Small things become patterns.'), findsNothing);
    await snap(tester, 'record_start_here_ready.png');
    VisualAuditFixtures.clearRecordOverride();
  });
}
