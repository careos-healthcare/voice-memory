import 'dart:io';

import 'package:archiveme_mobile/features/export/private_recap_model.dart';
import 'package:archiveme_mobile/features/export/private_recap_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

PrivateRecap _recap() => const PrivateRecap(
  type: PrivateRecapType.pattern,
  title: 'Taking on too much',
  dateRange: 'Seen 4 times',
  summary: 'Based on 4 check-ins',
  usefulMoments: ['Gets lighter when: I paused'],
  nextCheck: 'What happens right before it shows up?',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    clipboardText = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copyToClipboard writes the recap plain text', () async {
    final recap = _recap();
    final ok = await PrivateRecapService.copyToClipboard(recap);
    expect(ok, isTrue);
    expect(clipboardText, recap.plainText);
  });

  test(
    'shareText falls back to copy when native share is unavailable',
    () async {
      final recap = _recap();
      final shared = await PrivateRecapService.shareText(recap);
      expect(shared, isFalse);
      expect(clipboardText, recap.plainText);
    },
  );

  test('saveText writes a file with the recap text', () async {
    final dir = await Directory.systemTemp.createTemp('vm_recap_test');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final path = await PrivateRecapService.saveText(_recap(), directory: dir);
    expect(path, isNotNull);
    final file = File(path!);
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), _recap().plainText);
  });

  test('canSave is true on non-web platforms', () {
    expect(PrivateRecapService.canSave, isTrue);
  });
}