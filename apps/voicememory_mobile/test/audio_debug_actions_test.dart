import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_debug_actions.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_audio_session.dart';

void main() {
  tearDown(() async {
    IosNativeAudioSession.testPlaybackInvoker = null;
    AudioDebugActions.testPlayInvoker = null;
    await AudioDebugActions.dispose();
  });

  test('extensionFromPath supports wav and m4a', () {
    expect(
      AudioDebugActions.extensionFromPath('/tmp/vm_rec_123.wav'),
      'wav',
    );
    expect(
      AudioDebugActions.extensionFromPath('/tmp/vm_rec_123.m4a'),
      'm4a',
    );
  });

  test('playRecording logs missing path without throwing', () async {
    final lines = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    await AudioDebugActions.playRecording(null);

    expect(
      lines.any((line) => line.contains('ARCHIVEME_AUDIO_PLAYBACK_FAILED')),
      isTrue,
    );
  });

  test('playRecording logs missing file without throwing', () async {
    final lines = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    await AudioDebugActions.playRecording('/tmp/vm_missing_recording.wav');

    expect(
      lines.any(
        (line) =>
            line.contains('ARCHIVEME_AUDIO_PLAYBACK_REQUEST') &&
            line.contains('ext=wav') &&
            line.contains('exists=false'),
      ),
      isTrue,
    );
    expect(
      lines.any((line) => line.contains('ARCHIVEME_AUDIO_PLAYBACK_FAILED')),
      isTrue,
    );
  });

  testWidgets('playRecording shows snackbar when file is missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => AudioDebugActions.playRecording(
                  '/tmp/vm_missing_recording.wav',
                  context: context,
                ),
                child: const Text('Play'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recording file not found.'), findsOneWidget);
  });

  testWidgets('sharePositionOrigin returns non-zero rect from render box', (
    tester,
  ) async {
    Rect? origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            origin = AudioDebugActions.sharePositionOrigin(context);
            return const SizedBox(width: 120, height: 40);
          },
        ),
      ),
    );
    await tester.pump();

    expect(origin, isNotNull);
    expect(origin!.width, greaterThan(0));
    expect(origin!.height, greaterThan(0));
  });

  test('configureForPlayback logs session ready category', () async {
    IosNativeAudioSession.testPlaybackInvoker = () async {
      return const IosAudioSessionSnapshot(
        configured: true,
        category: 'playAndRecord',
        mode: 'default',
      );
    };

    final lines = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    final snapshot = await IosNativeAudioSession.configureForPlayback();
    expect(snapshot?.category, 'playAndRecord');
    expect(
      lines.any(
        (line) =>
            line.contains('ARCHIVEME_AUDIO_PLAYBACK_SESSION_READY') &&
            line.contains('category=playAndRecord'),
      ),
      isTrue,
    );
  });

  test('playback request log format includes wav metadata', () {
    final lines = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    AudioDiagLog.playbackRequest(
      path: '/tmp/vm_rec_test.wav',
      exists: true,
      bytes: 441044,
      extension: 'wav',
    );

    expect(
      lines.single,
      'ARCHIVEME_AUDIO_PLAYBACK_REQUEST path=/tmp/vm_rec_test.wav '
      'exists=true bytes=441044 ext=wav',
    );
  });
}
