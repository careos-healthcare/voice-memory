import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_code_actions.dart';

void main() {
  const code = 'abcd.efgh.ijkl.mnop';
  final createdAt = DateTime.utc(2026, 8, 4, 3, 2, 1);

  test('copy sends only the exact in-memory recovery code', () async {
    String? copied;
    final actions = SyncRecoveryCodeActions(
      clipboardWriter: (value) async => copied = value,
    );

    await actions.copy(code);

    expect(copied, code);
  });

  test('printable instructions contain required recovery guidance', () {
    final printable = SyncRecoveryCodeActions.buildPrintableInstructions(
      recoveryCode: code,
      createdAt: createdAt,
      envelopeRevision: 7,
    );

    expect(printable, contains(code));
    expect(printable, contains('2026-08-04T03:02:01.000Z'));
    expect(printable, contains('Safe reference: recovery revision 7'));
    expect(printable, contains('same ArchiveMe account'));
    expect(printable, contains('Store this page offline'));
    expect(printable, contains('permanently impossible'));
    expect(printable, contains('before disabling recovery'));
  });

  test('print temporary file is deleted after successful handoff', () async {
    final directory = await Directory.systemTemp.createTemp('recovery-print-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    String? handedOffPath;
    String? handedOffContents;
    final actions = SyncRecoveryCodeActions(
      temporaryDirectory: () async => directory,
      printHandoff: (file, subject) async {
        handedOffPath = file.path;
        handedOffContents = await file.readAsString();
        expect(subject, 'ArchiveMe recovery instructions');
        expect(await file.exists(), isTrue);
      },
    );

    await actions.printInstructions(
      recoveryCode: code,
      createdAt: createdAt,
      envelopeRevision: 2,
    );

    expect(handedOffContents, contains(code));
    expect(await File(handedOffPath!).exists(), isFalse);
  });

  test('print temporary file is deleted after cancel or error', () async {
    final directory = await Directory.systemTemp.createTemp('recovery-print-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    String? handedOffPath;
    final actions = SyncRecoveryCodeActions(
      temporaryDirectory: () async => directory,
      printHandoff: (file, subject) async {
        handedOffPath = file.path;
        throw StateError('platform handoff cancelled');
      },
    );

    await expectLater(
      actions.printInstructions(
        recoveryCode: code,
        createdAt: createdAt,
        envelopeRevision: 2,
      ),
      throwsStateError,
    );

    expect(await File(handedOffPath!).exists(), isFalse);
  });

  test(
    'print uses an opaque directory and never follows a fixed-name link',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recovery-print-',
      );
      final outside = await Directory.systemTemp.createTemp(
        'recovery-outside-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      final secret = File('${outside.path}/secret.txt');
      await secret.writeAsString('must-not-be-overwritten');
      final predictable = File(
        '${directory.path}/archive-me-recovery-${createdAt.toUtc().microsecondsSinceEpoch}.txt',
      );
      await Link(predictable.path).create(secret.path);
      String? handedOffPath;
      final actions = SyncRecoveryCodeActions(
        temporaryDirectory: () async => directory,
        printHandoff: (file, _) async => handedOffPath = file.path,
      );

      await actions.printInstructions(
        recoveryCode: code,
        createdAt: createdAt,
        envelopeRevision: 2,
      );

      expect(handedOffPath, isNot(predictable.path));
      expect(handedOffPath, contains('.archiveme_recovery_print_'));
      expect(await secret.readAsString(), 'must-not-be-overwritten');
      expect(await Link(predictable.path).exists(), isTrue);
    },
  );
}
