import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/demo/demo_share_pack.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_copy.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_demo_paths.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_mode.dart';
import 'package:voicememory_mobile/features/help/help_reviewer_guide_copy.dart';
import 'package:voicememory_mobile/screens/sample_archive_context_screen.dart';
import 'package:voicememory_mobile/screens/sample_archive_screen.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/demo/sample_archive_demo_paths_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sample archive demo paths copy', () {
    test('uses ArchiveMe-facing labels and example/sample wording', () {
      const visible = [
        SampleArchiveCopy.demoPathsTitle,
        SampleArchiveCopy.demoPathsIntro,
        SampleArchiveCopy.demoPathsFooterOne,
        SampleArchiveCopy.demoPathsFooterTwo,
        SampleArchiveCopy.demoPathStartTitle,
        SampleArchiveCopy.demoPathEvidenceMapTitle,
        SampleArchiveCopy.demoPathWorkContextTitle,
        SampleArchiveCopy.demoPathCopySummaryTitle,
        SampleArchiveCopy.demoPathBackArchiveTitle,
        SampleArchiveCopy.sampleContextBanner,
        HelpReviewerGuideCopy.sectionQuickValueBulletFive,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(SampleArchiveCopy.demoPathsIntro, contains('example'));
      expect(SampleArchiveCopy.demoPathsFooterOne, contains('private archive'));
      expect(
        HelpReviewerGuideCopy.sectionQuickValueBulletFive,
        contains('example data only'),
      );
    });
  });

  group('Sample archive demo paths wiring', () {
    test('router registers sample context route', () {
      final src = File('lib/router/app_router.dart').readAsStringSync();
      expect(src, contains('SampleArchiveDemoPaths.sampleContextRoute'));
      expect(src, contains('SampleArchiveContextScreen'));
    });

    test('demo paths do not write to JournalStore', () async {
      final tempDir = Directory.systemTemp.createTempSync('demo_paths_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      SampleArchiveDemoPaths.paths;
      DemoSharePackEngine.build();
      SampleArchiveEntries.build();

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });
  });

  group('Sample archive demo paths UI', () {
    testWidgets('Sample Archive shows Good demo paths section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const SampleArchiveScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('sample_archive_demo_paths_card')),
        findsOneWidget,
      );
      expect(find.text(SampleArchiveCopy.demoPathsTitle), findsOneWidget);
      expect(find.text(SampleArchiveCopy.demoPathsIntro), findsOneWidget);
      expect(
        find.byKey(const Key('sample_archive_demo_path_work_context')),
        findsOneWidget,
      );
    });

    testWidgets('Open Work context routes to sample context screen', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/sample-archive',
            builder: (context, state) => const SampleArchiveScreen(),
          ),
          GoRoute(
            path: SampleArchiveDemoPaths.sampleContextRoute,
            builder: (context, state) => SampleArchiveContextScreen(
              contextTagId: state.pathParameters['tagId'] ?? '',
            ),
          ),
        ],
        initialLocation: '/sample-archive',
      );

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final workPath = find.byKey(
        const Key('sample_archive_demo_path_work_context'),
      );
      await tester.ensureVisible(workPath);
      await tester.tap(workPath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('sample_archive_context_screen')),
        findsOneWidget,
      );
      expect(find.text(SampleArchiveCopy.sampleContextBanner), findsOneWidget);
      for (final entry in SampleArchiveEntries.build()) {
        if (entry.captureContextTag ==
            SampleArchiveDemoPaths.workContextTagId) {
          expect(
            find.byKey(Key('sample_archive_context_item_${entry.id}')),
            findsOneWidget,
          );
        }
      }
      for (final entry in SampleArchiveEntries.build()) {
        expect(SampleArchiveMode.isSampleEntry(entry), isTrue);
      }
    });

    testWidgets('Copy demo summary uses demo share pack only', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SampleArchiveDemoPathsCard(
              scrollController: ScrollController(),
              evidenceMapKey: GlobalKey(),
            ),
          ),
        ),
      );
      await tester.pump();

      final copyPath = find.byKey(
        const Key('sample_archive_demo_path_copy_summary'),
      );
      await tester.ensureVisible(copyPath);
      await tester.tap(copyPath);
      await tester.pump();

      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      final pack = DemoSharePackEngine.build();
      expect((copyCall.arguments as Map)['text'], pack.plainText);
      expect(pack.plainText, isNot(contains('sample_archive_')));
    });
  });
}
