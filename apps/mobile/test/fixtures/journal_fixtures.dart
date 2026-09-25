import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';

class JournalTestEntry {
  const JournalTestEntry({
    required this.text,
    required this.payload,
    required this.latitude,
    required this.longitude,
    required this.audioUrl,
    required this.passphrase,
    required this.dateString,
    required this.mood,
    required this.location,
  });

  final String text;
  final EncryptedPayload payload;
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
  E2EEncryptionService? encryption,
}) async {
  final service = encryption ?? E2EEncryptionService();
  return JournalTestEntry(
    text: text,
    payload: await service.encryptText(text, passphrase),
    latitude: latitude,
    longitude: longitude,
    audioUrl: audioUrl,
    passphrase: passphrase,
    dateString: dateString,
    mood: mood,
    location: location,
  );
}
