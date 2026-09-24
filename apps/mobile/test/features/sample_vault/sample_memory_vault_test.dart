import 'dart:io';

import 'package:archiveme_mobile/features/sample_vault/interactive_vault_demo_screen.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_memory_vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SampleMemoryVaultService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    service = SampleMemoryVaultService(
      filePath: 'assets/sample_vault/sample_vault.db',
    );
  });

  tearDown(() async {
    await service.close();
  });

  test('sample vault ships 15 career, health, and project moments', () async {
    final db = await openDatabase(
      '${Directory.current.path}/assets/sample_vault/sample_vault.db',
      readOnly: true,
      singleInstance: false,
    );
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sample_entries'),
    );
    final themes = await db.rawQuery(
      'SELECT DISTINCT theme FROM sample_entries ORDER BY theme',
    );
    final width = Sqflite.firstIntValue(
      await db.rawQuery('SELECT length(embedding) FROM sample_entries LIMIT 1'),
    );
    await db.close();
    expect(count, 15);
    expect(themes.map((row) => row['theme']), ['career', 'health', 'projects']);
    expect(width, 384 * 4);
    final anxious = await service.search(
      'Find times I felt anxious about work',
    );
    final milestones = await service.search('Show project milestones');
    final sleep = await service.search('How have I been sleeping');

    expect(anxious, isNotEmpty);
    expect(anxious.first.entry.theme, 'career');
    expect(anxious.first.relevance, greaterThan(0));
    expect(anxious.map((hit) => hit.entry.id), contains('career-review'));

    expect(milestones.first.entry.theme, 'projects');
    expect(
      milestones.map((hit) => hit.entry.id),
      contains('project-prototype'),
    );

    expect(sleep.first.entry.theme, 'health');
    expect(SampleMemoryVaultService.vecQuery, contains('MATCH'));
  });

  testWidgets('prompts show relevance and the unlock button opens checkout', (
    tester,
  ) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: InteractiveVaultDemoScreen(
          service: service,
          onUnlock: () => unlocked = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Find times I felt anxious about work'), findsOneWidget);
    expect(find.text('Show project milestones'), findsOneWidget);
    expect(find.text('Unlock Your Personal Vault'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vault_prompt_milestones')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.textContaining('Relevance'), findsWidgets);
    expect(
      find.byKey(const Key('vault_hit_project-prototype')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('vault_unlock')));
    await tester.pump();
    expect(unlocked, isTrue);
  });
}
