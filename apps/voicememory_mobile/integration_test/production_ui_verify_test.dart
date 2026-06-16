import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/record/start_here_catalog.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/widgets/empty_states/search_empty_state.dart';

import '../tool/full_visual_audit.dart';

/// Production UI verification — screenshots under tool/screenshots/production_verify/
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Directory('tool/screenshots/production_verify');

  Future<void> snap(WidgetTester tester, String filename) async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    if (!kIsWeb && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final name = filename.replaceAll('.png', '');
    final bytes = await binding.takeScreenshot(name);
    final path = '${outDir.path}${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    debugPrint('Saved $path');
  }

  Future<void> go(WidgetTester tester, String route) async {
    appRouter.go(route);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
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

    // 1. Settings — production only
    await go(tester, '/settings');
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Archive Intelligence'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Export Archive'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('About ArchiveMe'), findsOneWidget);
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
    expect(find.text(EmptyArchiveCopy.intentionalEmptyTitle), findsOneWidget);
    await snap(tester, 'archive_empty_state.png');

    await go(tester, '/discover-yourself');
    expect(find.text(EmptyArchiveCopy.intentionalEmptyTitle), findsOneWidget);
    await snap(tester, 'discover_empty_state.png');

    await go(tester, '/timeline');
    expect(find.text(EmptyArchiveCopy.intentionalEmptyTitle), findsOneWidget);
    await snap(tester, 'timeline_empty_state.png');

    await go(tester, '/search');
    expect(find.text(SearchEmptyCopy.title), findsOneWidget);
    expect(find.text('Nothing to search yet'), findsOneWidget);
    expect(find.text(EmptyArchiveCopy.intentionalEmptyTitle), findsNothing);
    await snap(tester, 'search_empty_state.png');

    await go(tester, '/journal');
    expect(find.text(EmptyArchiveCopy.intentionalEmptyTitle), findsOneWidget);

    // 4. Record — first-time framing copy
    VisualAuditFixtures.setRecordIdle();
    await go(tester, '/record');
    expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    expect(find.text(RecordScreenFramingCopy.guidance), findsOneWidget);
    expect(find.text(RecordScreenFramingCopy.helperLine), findsOneWidget);
    expect(find.text(StartHereCatalog.sectionTitle), findsOneWidget);
    expect(find.text(StartHereCatalog.prompts.first), findsOneWidget);
    expect(find.text('Small things become patterns.'), findsNothing);
    await snap(tester, 'record_start_here_ready.png');
    VisualAuditFixtures.clearRecordOverride();
  });
}
