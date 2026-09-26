import 'dart:io';

import 'package:archiveme_mobile/features/export/services/auto_backup_service.dart';
import 'package:archiveme_mobile/features/settings/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a week-old backup is replaced and only three copies are kept', () async {
    final root = await Directory.systemTemp.createTemp('auto_backup');
    addTearDown(() => root.delete(recursive: true));
    final clock = DateTime.utc(2026, 9, 26, 12);
    DateTime? last = clock.subtract(const Duration(days: 8));
    var enabled = true;
    for (final name in ['a.zip', 'b.zip', 'c.zip']) {
      await File('${root.path}/${AutoBackupService.filePrefix}$name').writeAsBytes([1]);
    }

    final wrote = await AutoBackupService(
      readEnabled: () async => enabled,
      readLastBackup: () async => last,
      writeLastBackup: (at) async => last = at,
      loadEntries: () async => const [],
      exportZip: (_) async => [9, 9, 9],
      destinationDirectory: () async => root,
      now: () => clock,
    ).runIfDue();

    expect(wrote, isTrue);
    final kept = root
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toList();
    expect(kept, hasLength(AutoBackupService.retainedBackups));
    expect(kept.any((name) => name.contains('2026-09-26')), isTrue);
    expect(last, clock);
  });

  test('a recent backup is left alone', () async {
    var writes = 0;
    final wrote = await AutoBackupService(
      readEnabled: () async => true,
      readLastBackup: () async => DateTime.utc(2026, 9, 20),
      writeLastBackup: (_) async {},
      loadEntries: () async => const [],
      exportZip: (_) async {
        writes += 1;
        return [1];
      },
      destinationDirectory: () async => Directory.systemTemp,
      now: () => DateTime.utc(2026, 9, 26),
    ).runIfDue();
    expect(wrote, isFalse);
    expect(writes, 0);
  });

  testWidgets('settings offers the weekly backup switch', (tester) async {
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutomaticWeeklyBackupToggle(
            readEnabled: () async => enabled,
            writeEnabled: (value) async => enabled = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Automatic Weekly Backup'), findsOneWidget);
    expect(
      find.text(
        'Saves a fully encrypted copy of your journal and media to your device files every week.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settings_auto_encrypted_backup')));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
  });
}
