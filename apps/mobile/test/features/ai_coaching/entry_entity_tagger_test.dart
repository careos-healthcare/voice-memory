import 'package:archiveme_mobile/features/ai_coaching/entry_entity_tagger.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('extracts people, a place, and a mood on a background turn', () async {
    final tags = await EntryEntityTagger.extract(
      'I met Ada in London and felt calm.',
    );

    expect(tags.people, ['Ada']);
    expect(tags.locations, ['London']);
    expect(tags.mood, 'calm');
    expect(tags.labels, ['person:Ada', 'place:London', 'mood:calm']);
  });

  test('dispatch stores tags without waiting on the caller', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    EntryEntityTagger.bind(db);

    dispatchTranscriptReady(
      'I met Ada in London and felt calm.',
      entryId: 'entry-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final saved = await EntryEntityTagger.store!.read('entry-1');
    expect(saved?.people, ['Ada']);
    expect(saved?.locations, ['London']);
    expect(saved?.mood, 'calm');
  });
}
