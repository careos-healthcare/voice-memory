import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:voicememory_mobile/features/live_audio/domain/services/live_audio_protocol.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';

void main() {
  group('LiveAudioProtocol', () {
    test('buildAudioInputMessage uses realtimeInput.audio at 16kHz', () {
      final frame = LiveAudioProtocol.buildAudioInputMessage([1, 2, 3, 4]);
      expect(
        frame['realtimeInput'],
        {
          'audio': {
            'mimeType': liveInputAudioMime,
            'data': base64Encode([1, 2, 3, 4]),
          },
        },
      );
      final validation = LiveAudioProtocol.validateClientMessage(frame);
      expect(validation.ok, isTrue);
    });

    test('rejects deprecated mediaChunks client frames', () {
      final validation = LiveAudioProtocol.validateClientMessage({
        'realtimeInput': {
          'mediaChunks': [
            {'mimeType': 'audio/pcm', 'data': 'AQID'},
          ],
        },
      });
      expect(validation.ok, isFalse);
      expect(validation.reason, 'deprecated_media_chunks');
    });

    test('parses setupComplete server frame', () {
      final events = LiveAudioProtocol.parseServerJson('{"setupComplete": {}}');
      expect(events, const [LiveSetupCompleteEvent()]);
    });

    test('parses inline audio output from serverContent', () {
      final events = LiveAudioProtocol.parseServerJson('''
{
  "serverContent": {
    "modelTurn": {
      "parts": [
        {
          "inlineData": {
            "mimeType": "audio/pcm;rate=24000",
            "data": "${base64Encode([9, 8, 7])}"
          }
        }
      ]
    }
  }
}
''');
      expect(events.length, 1);
      final event = events.single;
      expect(event, isA<LiveAudioOutputEvent>());
      expect((event as LiveAudioOutputEvent).pcmBytes, [9, 8, 7]);
    });
  });
}
