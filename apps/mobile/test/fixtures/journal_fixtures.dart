import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';

abstract final class JournalFixtures {
  JournalFixtures._();

  static const testPassphrase = 'thoughtprint-secure-key-2026';

  static const rawEntryJson = {
    'id': 'entry-river-2026',
    'timestamp': '2026-03-08T15:04:00.000Z',
    'transcript': 'the river was high after the rain',
    'mood': 'quiet',
    'latitude': 51.51,
    'longitude': -0.12,
    'audioUrl': 'thoughtprint://entry/entry-river-2026',
    'language': 'en',
  };

  static List<JournalBookEntry> getBookEntriesFixture() {
    return const [
      JournalBookEntry(
        dateString: '2026-03-08',
        transcript: 'the river was high after the rain',
        mood: 'quiet',
        location: 'bridge',
        audioQrUrl: 'thoughtprint://entry/entry-river-2026',
      ),
      JournalBookEntry(
        dateString: '2026-06-14',
        transcript: 'market was loud and I left early',
        mood: 'restless',
        location: 'market',
        audioQrUrl: 'thoughtprint://entry/entry-market-2026',
      ),
      JournalBookEntry(
        dateString: '2026-09-25',
        transcript: 'walked home without the umbrella',
        location: 'home',
      ),
    ];
  }

  static String getExportArchiveJson() {
    return jsonEncode({
      'schemaVersion': 1,
      'passphraseHint': 'stored only in the test',
      'entries': [
        rawEntryJson,
        {
          'id': 'entry-market-2026',
          'timestamp': '2026-06-14T09:20:00.000Z',
          'transcript': 'market was loud and I left early',
          'mood': 'restless',
          'latitude': 51.52,
          'longitude': -0.11,
          'audioUrl': 'thoughtprint://entry/entry-market-2026',
          'language': 'en',
        },
        {
          'id': 'entry-home-2026',
          'timestamp': '2026-09-25T18:00:00.000Z',
          'transcript': 'walked home without the umbrella',
          'mood': null,
          'latitude': 51.50,
          'longitude': -0.13,
          'audioUrl': 'thoughtprint://entry/entry-home-2026',
          'language': 'en',
        },
      ],
    });
  }
}

class JournalTestEntry {
  const JournalTestEntry({
    required this.text,
    required this.ciphertext,
    required this.accountKey,
    required this.latitude,
    required this.longitude,
    required this.audioUrl,
    required this.passphrase,
    required this.dateString,
    required this.mood,
    required this.location,
  });

  final String text;
  final String ciphertext;
  final List<int> accountKey;
  final double latitude;
  final double longitude;
  final String audioUrl;
  final String passphrase;
  final String dateString;
  final String mood;
  final String location;
}

Future<JournalTestEntry> makeJournalEntry({
  String text = 'the river was high',
  String passphrase = 'correct horse',
  double latitude = 51.51,
  double longitude = -0.12,
  String audioUrl = 'thoughtprint://entry/river',
  String dateString = '2026-03-08',
  String mood = 'quiet',
  String location = 'bridge',
}) async {
  final accountKey = AccountSyncKey.generate(Random(4));
  final sealed = await RecordSync.seal(
    accountKey: accountKey,
    recordId: 'fixture',
    kind: SyncRecordKind.entry,
    version: 1,
    updatedAt: DateTime.utc(2026, 3, 8),
    deviceId: 'test',
    plaintext: {'transcript': text, 'passphrase': passphrase},
  );
  return JournalTestEntry(
    text: text,
    ciphertext: sealed.ciphertext,
    accountKey: accountKey,
    latitude: latitude,
    longitude: longitude,
    audioUrl: audioUrl,
    passphrase: passphrase,
    dateString: dateString,
    mood: mood,
    location: location,
  );
}
