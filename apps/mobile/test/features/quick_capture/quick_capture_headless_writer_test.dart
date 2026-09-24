import 'dart:io';

import 'package:archiveme_mobile/features/quick_capture/quick_capture_headless_writer.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_home_widget_config.dart';
import 'package:archiveme_mobile/startup/cold_start_deferred_work.dart';
import 'package:archiveme_mobile/storage/recent_entry_snippet_cache.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  setUp(() {
    ColdStartDeferredWork.resetForTest();
    RecentEntrySnippetCache.resetForTest();
  });

  test('desktop shortcut text is read from the argument', () {
    expect(
      QuickCaptureHomeWidgetConfig.textFromDesktopArguments(const [
        '--quick-capture=morning note',
      ]),
      'morning note',
    );
    expect(
      QuickCaptureHomeWidgetConfig.textFromUri(
        QuickCaptureHomeWidgetConfig.uriForText('morning note'),
      ),
      'morning note',
    );
    expect(
      QuickCaptureHomeWidgetConfig.androidProvider,
      'QuickCaptureWidgetProvider',
    );
    expect(QuickCaptureHomeWidgetConfig.iosWidgetName, 'QuickCaptureWidget');
  });

  test('headless write stores sqlite and the feed snippet', () async {
    final dir = await Directory.systemTemp.createTemp(
      'quick_capture_headless_',
    );
    addTearDown(() async {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final db = await SqliteDatabaseInitializer.open(
      filePath: '${dir.path}/archiveme.db',
      passwordOverride: SqliteDatabaseInitializer.testEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    addTearDown(db.close);

    expect(ColdStartDeferredWork.pendingCount, 0);
    expect(ColdStartDeferredWork.hasStarted, isFalse);

    final snippetFile = File(
      '${dir.path}/${RecentEntrySnippetCache.fileName}',
    );
    final entry = await QuickCaptureHeadlessWriter.writeText(
      database: db,
      snippetFile: snippetFile,
      text: 'Widget note from the home screen',
      createdAt: DateTime.utc(2026, 9, 21, 12),
      entryId: 'widget-1',
    );

    final rows = await db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    expect(rows.single['transcript'], 'Widget note from the home screen');
    expect(RecentEntrySnippetCache.instance.snippets.single.id, 'widget-1');

    RecentEntrySnippetCache.resetForTest();
    await RecentEntrySnippetCache.instance.hydrateFromFile(snippetFile);
    expect(
      RecentEntrySnippetCache.instance.snippets.single.text,
      'Widget note from the home screen',
    );
  });
}
