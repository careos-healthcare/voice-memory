import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/audio/audio_session_manager.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/capture/controllers/live_voice_session.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_native_audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _HoldTimer implements Timer {
  _HoldTimer(this._onFire);

  final void Function() _onFire;
  var _cancelled = false;

  void fire() {
    if (_cancelled) return;
    _cancelled = true;
    _onFire();
  }

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  tearDown(() {
    IosNativeAudioSession.testInvoker = null;
  });

  test('reflect mode asks iOS for voice chat and Android for communication', () async {
    IosCaptureAudioMode? iosMode;
    IosNativeAudioSession.testInvoker = (mode) async {
      iosMode = mode;
      return IosAudioSessionSnapshot(
        configured: true,
        category: AudioSessionManager.iosCategory,
        mode: mode.value,
      );
    };
    var androidCalls = 0;
    final manager = AudioSessionManager(
      ios: true,
      android: true,
      configureAndroid: () async {
        androidCalls += 1;
      },
    );

    await manager.enterReflectMode();

    expect(iosMode, IosCaptureAudioMode.voiceChat);
    expect(iosMode?.value, AudioSessionManager.iosMode);
    expect(androidCalls, 1);
    expect(AudioSessionManager.androidMode, 'MODE_IN_COMMUNICATION');

    final swift = File(
      'ios/Runner/IosCaptureAudioSession.swift',
    ).readAsStringSync();
    expect(swift, contains('.voiceChat'));
    expect(swift, contains('.playAndRecord'));
  });

  test('a local template is used, and the cloud is skipped when sync is off', () async {
    var cloudCalls = 0;
    final generator = ReflectQuestionGenerator(
      cloudSyncEnabled: false,
      cloudQuestion: (_) async {
        cloudCalls += 1;
        return 'Should not be spoken.';
      },
    );

    final question = await generator.next(transcript: 'the river', turn: 0);

    expect(question, 'What stood out just then?');
    expect(cloudCalls, 0);
  });

  test('an older entry is woven in, and gemma replaces the cloud', () async {
    var cloudCalls = 0;
    final generator = ReflectQuestionGenerator(
      cloudSyncEnabled: true,
      findSimilarEntries: (_) async => [
        SimilarEntry(
          id: 'past',
          transcript: 'I kept walking by the river after work.',
          createdAt: DateTime.utc(2026, 1, 2),
          cosineSimilarity: 0.9,
        ),
      ],
      rephrase: (draft) async => 'What changed by the river?',
      cloudQuestion: (_) async {
        cloudCalls += 1;
        return 'Cloud question.';
      },
    );

    final question = await generator.next(transcript: 'the river', turn: 0);

    expect(question, 'What changed by the river?');
    expect(cloudCalls, 0);
  });

  test('the cloud is asked only when sync is on and nothing local rephrased it', () async {
    final generator = ReflectQuestionGenerator(
      cloudSyncEnabled: true,
      rephrase: (_) async => null,
      cloudQuestion: (_) async => 'What feels unfinished there?',
    );

    expect(
      await generator.next(transcript: 'the river', turn: 1),
      'What feels unfinished there?',
    );
  });

  test('1.5 seconds of silence asks once, and speech resets the wait', () async {
    final waits = <Duration>[];
    _HoldTimer? pending;
    final session = ReflectWithMeSession(
      questions: ReflectQuestionGenerator(),
      readAloud: ReadAloudService(speakText: (_) async {}),
      startTimer: (duration, callback) {
        waits.add(duration);
        final timer = _HoldTimer(callback);
        pending = timer;
        return timer;
      },
    );
    session.notePartial('the deadline moved');
    session.onSpeechStart();
    session.noteLevel(-20);
    session.noteLevel(-50);
    expect(session.appTurns, 0);
    expect(waits, [const Duration(milliseconds: 1500)]);

    final first = pending!;
    session.noteLevel(-20);
    expect(first.isActive, isFalse);

    session.noteLevel(-50);
    expect(waits, hasLength(2));
    pending!.fire();
    await _settle();
    expect(session.appTurns, 1);
    expect(session.questions.single, 'What stood out just then?');
  });

  test('speech during playback stops the question', () async {
    var stopped = 0;
    final gate = Completer<void>();
    _HoldTimer? pending;
    final session = ReflectWithMeSession(
      questions: ReflectQuestionGenerator(),
      readAloud: ReadAloudService(
        speakText: (_) => gate.future,
        stopPlayback: () async {
          stopped += 1;
          if (!gate.isCompleted) gate.complete();
        },
      ),
      startTimer: (_, callback) {
        final timer = _HoldTimer(callback);
        pending = timer;
        return timer;
      },
    );
    session.notePartial('the river');
    session.onSpeechStart();
    session.noteLevel(-50);
    pending!.fire();
    await _settle();
    expect(session.readingAloud, isTrue);

    session.onSpeechStart();
    await _settle();

    expect(stopped, 1);
    expect(session.readingAloud, isFalse);
  });

  test('the fourth silence stays a normal recording', () async {
    _HoldTimer? pending;
    final session = ReflectWithMeSession(
      questions: ReflectQuestionGenerator(),
      readAloud: ReadAloudService(speakText: (_) async {}),
      startTimer: (_, callback) {
        final timer = _HoldTimer(callback);
        pending = timer;
        return timer;
      },
    );
    for (var turn = 0; turn < 3; turn++) {
      session.onSpeechStart();
      session.noteLevel(-50);
      pending!.fire();
      await _settle();
    }
    expect(session.appTurns, 3);
    expect(session.fellBackToRecording, isTrue);

    session.onSpeechStart();
    session.noteLevel(-50);
    expect(pending!.isActive, isFalse);
    expect(session.appTurns, 3);
    expect(session.questions, hasLength(3));
  });
}
