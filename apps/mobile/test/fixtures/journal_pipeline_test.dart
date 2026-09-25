import 'dart:io';

import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:archiveme_mobile/features/capture/controllers/live_speech_controller.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_fixtures.dart';

class _ScriptedSpeech extends LiveSpeechEngine {
  void Function(String words)? onPartial;

  @override
  Future<void> start({
    required void Function(String words) onPartial,
    required void Function(double level) onLevel,
  }) async {
    this.onPartial = onPartial;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  test('a spoken line is encrypted, restored, and printed', () async {
    final speech = _ScriptedSpeech();
    final controller = LiveSpeechController(engine: speech);
    await controller.startListening();
    speech.onPartial!('the river was high');
    final spoken = controller.transcript;
    controller.dispose();

    const passphrase = 'correct horse';
    final service = E2EEncryptionService();
    final entry = await makeJournalEntry(
      text: spoken,
      passphrase: passphrase,
      encryption: service,
    );
    expect(entry.payload.ciphertext, isNot(contains(spoken)));

    final restored = await service.decryptText(entry.payload, passphrase);
    expect(restored, spoken);

    final dir = await Directory.systemTemp.createTemp('journal_pipeline_');
    final file = await BookExporter.save(
      JournalBook(
        title: 'River notes',
        entries: [
          JournalBookEntry(
            dateString: entry.dateString,
            transcript: restored,
            mood: entry.mood,
            location: entry.location,
            audioQrUrl: entry.audioUrl,
          ),
        ],
      ),
      path: '${dir.path}/journal.pdf',
    );
    expect(await file.length(), greaterThan(0));
  });
}
