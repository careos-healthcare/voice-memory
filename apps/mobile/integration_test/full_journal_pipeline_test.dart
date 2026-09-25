import 'dart:io';

import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:archiveme_mobile/features/capture/controllers/live_speech_controller.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/journal_fixtures.dart';

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a spoken line is encrypted, restored, and printed', (tester) async {
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
    expect(entry.latitude, isNot(0));
    expect(entry.audioUrl, startsWith('thoughtprint://'));

    final restored = await service.decryptText(entry.payload, passphrase);
    expect(restored, spoken);

    final dir = await Directory.systemTemp.createTemp('journal_pipeline_');
    final file = await BookExporter.save(
      JournalBook(
        title: 'River notes',
        author: 'Ada',
        entries: [
          JournalBookEntry(
            dateString: entry.dateString,
            transcript: restored,
            mood: entry.mood,
            location: '${entry.location} ${entry.latitude},${entry.longitude}',
            audioQrUrl: entry.audioUrl,
          ),
        ],
      ),
      path: '${dir.path}/journal.pdf',
    );
    final bytes = await file.readAsBytes();
    expect(bytes, isNotEmpty);
    expect(file.path, endsWith('.pdf'));
  });
}
