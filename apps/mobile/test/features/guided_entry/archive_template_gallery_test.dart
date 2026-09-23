import 'dart:io';

import 'package:archiveme_mobile/features/archive_analyst/archive_belief_visibility.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_engine.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_materializer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_sqlite_writer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/archive_template_gallery.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  final clock = DateTime.utc(2026, 9, 23, 12);

  test('each template scores a visible pattern before it is saved', () {
    const engine = ArchiveTheoryEngine();
    for (final template in ArchiveEntryTemplates.all) {
      final draft = ArchiveTemplateMaterializer.materialize(
        template,
        now: clock,
        engine: engine,
      );
      final pattern = draft.pattern;
      expect(pattern, isNotNull, reason: template.id);
      expect(
        ArchiveBeliefVisibility.isVisibleTheory(pattern!),
        isTrue,
        reason: template.id,
      );
      expect(pattern.evidenceCount, greaterThanOrEqualTo(3));
      expect(
        pattern.confidencePercent,
        greaterThanOrEqualTo(ArchiveBeliefVisibility.minConfidencePercent),
      );
      expect(pattern.statement, template.patternStatement);
    }
  });

  test('tapping a template writes the page and moments into SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('archive_template_');
    addTearDown(() => dir.delete(recursive: true));
    final sqlite = await AppSqliteDatabase.open(
      filePath: '${dir.path}/journal.sqlite',
      password: testSqliteEncryptionPassword,
    );
    final repository = JournalSqliteRepository(sqlite);
    final writer = ArchiveTemplateSqliteWriter(repository);

    final draft = await writer.apply(
      ArchiveEntryTemplates.leaveBeforeDinner,
      now: clock,
    );

    final stored = await repository.fetchPage(offset: 0, limit: 20);
    expect(
      stored.map((entry) => entry.id).toSet(),
      draft.entries.map((entry) => entry.id).toSet(),
    );
    expect(
      stored.map((entry) => entry.transcript),
      contains(draft.page.transcript),
    );

    final scored = const ArchiveTheoryEngine().build(
      entries: stored,
      statement: draft.template.patternStatement,
      lastUpdated: clock,
    );
    expect(scored, isNotNull);
    expect(scored!.evidenceCount, greaterThanOrEqualTo(3));
  });

  testWidgets('tapping a template asks the host to open that page', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ArchiveTemplateGallery(
            now: clock,
            onViewEvidence: (_) => opened.add('evidence'),
            onOpenTemplate: (template) async {
              opened.add(template.id);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('archive_template_pattern_leave-before-dinner')),
      findsOneWidget,
    );
    expect(find.textContaining('View evidence'), findsWidgets);
    expect(find.textContaining('moments line up'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('archive_template_card_leave-before-dinner')),
    );
    await tester.pump();

    expect(opened, ['leave-before-dinner']);
  });
}
