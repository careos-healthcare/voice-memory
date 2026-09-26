import 'dart:io';

import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:archiveme_mobile/features/import/voice_memo_importer.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a shared m4a is transcribed in the chosen language and backdated',
    () async {
      final dir = await Directory.systemTemp.createTemp('voice_memo_');
      final audio = File('${dir.path}/morning.m4a')
        ..writeAsBytesSync([1, 2, 3]);
      final recorded = DateTime.utc(2024, 5, 2, 8);
      ConfirmedSpeechLocale? seen;
      final entry = await VoiceMemoImporter.importFile(
        audio: audio,
        locale: ConfirmedSpeechLocale.confirmed('es-ES')!,
        createdAt: recorded,
        transcribe: (file, locale) async {
          seen = locale;
          expect(file.path, audio.path);
          return 'el rio estaba alto';
        },
      );
      expect(seen?.identifier, 'es-ES');
      expect(entry?.transcript, 'el rio estaba alto');
      expect(entry?.createdAt, recorded);
      expect(entry?.captureSource, VoiceMemoImporter.captureSource);
      final undated = await VoiceMemoImporter.importFile(
        audio: audio,
        locale: ConfirmedSpeechLocale.confirmed('es-ES')!,
        transcribe: (file, locale) async => 'should not date itself today',
      );
      expect(undated, isNull);
      expect(entry?.localAudioPath, audio.path);
      expect(VoiceMemoImporter.accepts('note.wav'), isTrue);
      expect(VoiceMemoImporter.accepts('note.mp3'), isTrue);
      expect(VoiceMemoImporter.accepts('note.txt'), isFalse);
      final fromFile = await VoiceMemoImporter.importFile(
        audio: File('${dir.path}/evening.wav')..writeAsBytesSync([9]),
        locale: ConfirmedSpeechLocale.confirmed('es-ES')!,
        readCreationDate: (path) async => '2021-01-09T18:30:00.000Z',
        transcribe: (file, locale) async => 'from the file date',
      );
      expect(fromFile?.createdAt, DateTime.utc(2021, 1, 9, 18, 30));
      expect(fromFile?.transcript, 'from the file date');
      expect(fromFile?.localAudioPath, endsWith('evening.wav'));
      await dir.delete(recursive: true);
    },
  );

  test(
    'an opened voice memo is saved on the recording date without guessing a language',
    () async {
      final dir = await Directory.systemTemp.createTemp('voice_memo_inbox_');
      final audio = File('${dir.path}/shared.m4a')..writeAsBytesSync([4]);
      var transcribed = false;
      StateOfMindReader.debugLookup = (day) async => 'calm';
      addTearDown(() => StateOfMindReader.debugLookup = null);
      final saved = <JournalEntry>[];
      final entry = await VoiceMemoImportInbox.consume(
        pending: {
          'path': audio.path,
          'createdAt': '2023-11-04T15:00:00.000Z',
        },
        readLocale: () async => null,
        save: (row) async => saved.add(row),
        transcribe: (file, locale) async {
          transcribed = true;
          return 'should not run';
        },
      );
      expect(transcribed, isFalse);
      expect(entry?.transcript, isEmpty);
      expect(entry?.createdAt, DateTime.utc(2023, 11, 4, 15));
      expect(entry?.reflection.healthStateOfMind, isNull);
      expect(saved, hasLength(1));
      await dir.delete(recursive: true);
    },
  );

  test('state of mind for that day is stored on the entry', () async {
    StateOfMindReader.debugLookup = (day) async => 'calm';
    addTearDown(() => StateOfMindReader.debugLookup = null);
    final entry = JournalEntry(
      id: 'day',
      createdAt: DateTime.utc(2026, 9, 25),
      transcript: 'a walk',
      durationSeconds: 2,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
    final attached = await StateOfMindReader.attach(entry);
    expect(attached.reflection.healthStateOfMind, 'calm');
    expect(attached.toJson()['reflection']['healthStateOfMind'], 'calm');
  });

  test(
    'speech language settings are the locale native recognition reads',
    () async {
      final dir = await Directory.systemTemp.createTemp('speech_lang_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      await prefs.writeString(SpeechLocaleStore.settingsPreferenceKey, 'ja-JP');
      final locale = await SpeechLocaleStore(prefs).read();
      expect(locale?.identifier, 'ja-JP');
      await dir.delete(recursive: true);
    },
  );

  test('saving a moment does not read Apple Health', () {
    final capture = File(
      'lib/features/capture_flow/adapters/pipeline_capture_adapters.dart',
    ).readAsStringSync();
    final importer = File(
      'lib/features/import/voice_memo_importer.dart',
    ).readAsStringSync();
    expect(capture, isNot(contains('StateOfMindReader')));
    expect(importer, isNot(contains('StateOfMindReader')));
  });
}
