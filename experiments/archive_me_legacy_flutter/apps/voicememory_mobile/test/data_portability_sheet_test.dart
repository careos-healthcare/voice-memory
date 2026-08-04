import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/export_backup/ui/data_portability_sheet.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester,
    DataPortabilitySheet sheet, {
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(430, 900),
              textScaler: TextScaler.linear(textScale),
            ),
            child: sheet,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  Future<void> choosePassword(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('portability_password_mode')));
    await tester.pumpAndSettle();
  }

  Future<void> enterValidPassword(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('portability_password')),
      'correct horse battery',
    );
    await tester.enterText(
      find.byKey(const Key('portability_password_confirmation')),
      'correct horse battery',
    );
    await tester.tap(find.byKey(const Key('portability_password_continue')));
    await tester.pumpAndSettle();
  }

  testWidgets('restore confirms before picker and restore callback', (
    tester,
  ) async {
    var pickerCalls = 0;
    var restoreCalls = 0;
    await pumpSheet(
      tester,
      DataPortabilitySheet(
        pickMemoryVaultFile: () async {
          pickerCalls++;
          return '/tmp/archive.memoryvault';
        },
        onRestoreBackup: (path, credential) async {
          restoreCalls++;
          expect(path, endsWith('.memoryvault'));
          expect(credential.mode, DataPortabilityCredentialMode.customPassword);
        },
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('portability_restore_backup')),
    );
    await tester.pump();
    expect(pickerCalls, 0);
    expect(restoreCalls, 0);
    expect(find.text('Replace this vault?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('portability_restore_confirm')));
    await tester.pumpAndSettle();
    expect(pickerCalls, 1);
    expect(restoreCalls, 0);
    await choosePassword(tester);
    await enterValidPassword(tester);

    expect(restoreCalls, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    expect(find.byKey(const Key('portability_success')), findsOneWidget);
  });

  testWidgets('custom password requires matching 12 characters', (
    tester,
  ) async {
    var backupCalls = 0;
    await pumpSheet(
      tester,
      DataPortabilitySheet(
        onCreateBackup: (credential) async {
          backupCalls++;
          return null;
        },
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('portability_create_backup')),
    );
    await tester.pumpAndSettle();
    await choosePassword(tester);
    await tester.enterText(
      find.byKey(const Key('portability_password')),
      'too-short',
    );
    await tester.enterText(
      find.byKey(const Key('portability_password_confirmation')),
      'too-short',
    );
    await tester.tap(find.byKey(const Key('portability_password_continue')));
    await tester.pump();

    expect(
      find.text('Password must be at least 12 characters.'),
      findsOneWidget,
    );
    expect(backupCalls, 0);
  });

  testWidgets('recovery phrase mode accepts exactly twelve words', (
    tester,
  ) async {
    DataPortabilityCredential? received;
    await pumpSheet(
      tester,
      DataPortabilitySheet(
        onCreateBackup: (credential) async {
          received = credential;
          return null;
        },
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('portability_create_backup')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portability_phrase_mode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('portability_recovery_phrase')),
      'one two three four five six seven eight nine ten eleven twelve',
    );
    await tester.tap(find.byKey(const Key('portability_phrase_continue')));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.mode, DataPortabilityCredentialMode.recoveryPhrase);
    expect(received!.secret.split(' '), hasLength(12));
  });

  testWidgets('Markdown export authenticates biometrics before callback', (
    tester,
  ) async {
    final events = <String>[];
    await pumpSheet(
      tester,
      DataPortabilitySheet(
        authenticateForExport: () async {
          events.add('biometric');
          return true;
        },
        onExportMarkdown: () async {
          events.add('export');
          return '/tmp/memories.md';
        },
        shareFile: (path) async {
          events.add('share:$path');
        },
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('portability_export_markdown')),
    );
    await tester.pump();
    expect(events, isEmpty);
    await tester.tap(find.byKey(const Key('portability_markdown_confirm')));
    await tester.pumpAndSettle();

    expect(events, ['biometric', 'export', 'share:/tmp/memories.md']);
  });

  testWidgets('busy state reports progress and disables controls', (
    tester,
  ) async {
    final pending = Completer<String?>();
    await pumpSheet(
      tester,
      DataPortabilitySheet(
        readPassword: (_, _) async => 'correct horse battery',
        onCreateBackup: (_) => pending.future,
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('portability_create_backup')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portability_password_mode')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('portability_busy_indicator')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('portability_create_backup')),
          )
          .onPressed,
      isNull,
    );
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portability_busy_indicator')), findsNothing);
  });

  testWidgets('supports large Dynamic Type without layout exceptions', (
    tester,
  ) async {
    await pumpSheet(tester, const DataPortabilitySheet(), textScale: 2);

    expect(find.text('Export, backup & portability'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Human-readable export'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Human-readable export'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
