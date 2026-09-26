import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/reflect_question_policy.dart';
import 'package:archiveme_mobile/features/capture/services/entry_save_pipeline.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/live_draft_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/live_draft_transcript.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/streaming_speech_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('questions quote only words that were said and ask nothing else', () {
    const quote = 'I kept walking by the river after work.';
    final question = ReflectQuestionPolicy.localQuestion(
      lastSentence: 'the river was quiet',
      earlierQuote: quote,
      earlierOn: DateTime.utc(2026, 8, 3),
    );
    expect(question, "On 3 August you said '$quote'. What's different now?");
    expect(
      ReflectQuestionPolicy.accept(
        question: question,
        requiredQuote: quote,
        sources: [quote, 'the river was quiet'],
      ),
      isTrue,
    );
    expect(
      ReflectQuestionPolicy.accept(
        question: "You should rest. On 3 August you said '$quote'?",
        requiredQuote: quote,
        sources: [quote],
      ),
      isFalse,
    );
    expect(
      ReflectQuestionPolicy.accept(
        question: "On 3 August you said 'a sentence you did not say'?",
        sources: [quote],
      ),
      isFalse,
    );
  });

  test('a session asks at most three questions', () {
    expect(
      ReflectQuestionPolicy.canAskAnother(questionsAlreadyAsked: 2),
      isTrue,
    );
    expect(
      ReflectQuestionPolicy.canAskAnother(questionsAlreadyAsked: 3),
      isFalse,
    );
    expect(ReflectQuestionPolicy.maxQuestions, 3);
    expect(ReflectQuestionPolicy.isClosing("That's all."), isTrue);
  });

  test('app questions stay out of the saved transcript', () {
    const reflection = Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    );
    final saved = EntrySavePipeline.consolidate(
      entry: JournalEntry(
        id: 'entry',
        createdAt: DateTime.utc(2026, 9, 26),
        transcript: "Thoughtprint asked what's different",
        durationSeconds: 4,
        reflection: reflection,
      ),
      lines: [
        VoiceChatLine(
          role: VoiceChatRole.user,
          text: 'the river was quiet',
          at: DateTime.utc(2026, 9, 26, 12),
        ),
        VoiceChatLine(
          role: VoiceChatRole.app,
          text: "On 3 August you said 'I kept walking.'. What's different now?",
          at: DateTime.utc(2026, 9, 26, 12, 0, 2),
        ),
      ],
    );
    expect(saved.transcript, 'the river was quiet');
    expect(saved.transcript.contains('Thoughtprint'), isFalse);
    expect(saved.aiQuestions, hasLength(1));
  });

  test('Android streaming is on only when a recogniser exists', () {
    LiveDraftTranscript.debugAvailability = const LiveDraftAvailability(
      treatAsAndroid: true,
      platformRecognizerReady: true,
    );
    addTearDown(() => LiveDraftTranscript.debugAvailability = null);
    expect(LiveDraftTranscript.supportsOnDeviceStreaming, isTrue);

    LiveDraftTranscript.debugAvailability = const LiveDraftAvailability(
      treatAsAndroid: true,
    );
    expect(LiveDraftTranscript.supportsOnDeviceStreaming, isFalse);

    LiveDraftTranscript.debugAvailability = const LiveDraftAvailability(
      treatAsAndroid: true,
      sherpaReady: true,
    );
    expect(LiveDraftTranscript.supportsOnDeviceStreaming, isTrue);
  });

  test('a model download waits for Wi-Fi and says what it is doing', () async {
    final root = await Directory.systemTemp.createTemp('speech-model');
    addTearDown(() => root.delete(recursive: true));
    var fetched = false;
    final store = StreamingSpeechModelStore(
      supportDirectory: () async => root,
      wifiOnly: true,
      onWifi: () async => false,
      fetch: (_) async {
        fetched = true;
        return Uint8List(0);
      },
    );
    expect(await store.ensure(), isNull);
    expect(fetched, isFalse);
    expect(
      StreamingSpeechModel.downloadingLabel,
      'Downloading the on-device speech model',
    );
  });
}
