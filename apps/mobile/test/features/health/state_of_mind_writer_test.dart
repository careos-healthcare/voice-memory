import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppleHealthPlatform.debugIsIos = null;
    StateOfMindWriter.debugWriteEnabled = null;
    StateOfMindWriter.debugWrite = null;
  });

  test('writes a journal mood only on iOS when the setting is on', () async {
    final written = <String>[];
    AppleHealthPlatform.debugIsIos = true;
    StateOfMindWriter.debugWriteEnabled = false;
    StateOfMindWriter.debugWrite = (mood) async {
      written.add(mood);
    };

    expect(await StateOfMindWriter.writeJournalMood('Calm'), isFalse);
    expect(written, isEmpty);

    StateOfMindWriter.debugWriteEnabled = true;
    expect(await StateOfMindWriter.writeJournalMood('Calm'), isTrue);
    expect(written, ['Calm']);

    AppleHealthPlatform.debugIsIos = false;
    expect(await StateOfMindWriter.writeJournalMood('Anxious'), isFalse);
    expect(written, ['Calm']);
  });
}
