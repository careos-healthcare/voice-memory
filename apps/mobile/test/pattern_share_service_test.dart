import 'package:archiveme_mobile/features/pattern_memory/pattern_share_recap_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_share_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

PatternShareRecap _recap() => PatternShareRecap(
  id: 'share_weekly_1',
  createdAt: DateTime(2026, 6, 4),
  type: PatternShareRecapType.weekly,
  title: 'This week\u2019s pattern',
  body: 'This pattern kept showing up this week.',
  lines: const [
    'You checked it 4 times and caught it more than once.',
    'Next check: What happens right before it starts?',
  ],
  nextQuestion: 'What happens right before it starts?',
  plainText:
      'This week\u2019s pattern\n\n'
      'This pattern kept showing up this week.\n\n'
      '- You checked it 4 times and caught it more than once.\n'
      '- Next check: What happens right before it starts?\n\n'
      'Made with ArchiveMe',
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

  test('copyToClipboard returns true and writes the recap text', () async {
    final recap = _recap();
    final ok = await PatternShareService.copyToClipboard(recap);
    expect(ok, isTrue);
    expect(clipboardText, recap.plainText);
  });

  test('share fallback copies if native share unavailable', () async {
    // No mock for the share_plus channel, so Share.share throws and the
    // service falls back to copying the recap.
    final recap = _recap();
    final opened = await PatternShareService.shareText(recap);
    expect(opened, isFalse);
    expect(clipboardText, recap.plainText);
  });
}