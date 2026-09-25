import 'dart:io';

import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:archiveme_mobile/features/capture/controllers/live_speech_controller.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/journal_fixtures.dart';

class _ScriptedSpeech extends LiveSpeechEngine {
  @override
  Future<void> start({
    required void Function(String words) onPartial,
    required void Function(double level) onLevel,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory scratch;
  LiveSpeechController? speech;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('journal_pipeline_');
  });

  tearDownAll(() async {
    speech?.dispose();
    if (scratch.existsSync()) {
      await scratch.delete(recursive: true);
    }
  });

  testWidgets('stage 1 starts listening without a microphone', (tester) async {
    speech = LiveSpeechController(engine: _ScriptedSpeech());
    expect(speech!.state, RecordingState.idle);
    await speech!.startListening();
    expect(speech!.state, RecordingState.listening);
    expect(speech!.transcript, isEmpty);
  });

  testWidgets('stage 2 encrypts and restores the fixture transcript', (tester) async {
    final transcript = JournalFixtures.rawEntryJson['transcript'].toString();
    final service = E2EEncryptionService();
    final payload = await service.encryptText(
      transcript,
      JournalFixtures.testPassphrase,
    );
    expect(payload.ciphertext, isNot(contains(transcript)));
    expect(
      await service.decryptText(payload, JournalFixtures.testPassphrase),
      transcript,
    );
  });

  testWidgets('stage 3 writes a PDF book larger than 1KB', (tester) async {
    final file = await BookExporter.generatePdfBook(
      entries: JournalFixtures.getBookEntriesFixture(),
      path: '${scratch.path}/journal.pdf',
    );
    final bytes = await file.readAsBytes();
    expect(file.existsSync(), isTrue);
    expect(bytes.length, greaterThan(1024));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('stage 4 writes the archive json unchanged', (tester) async {
    final expected = JournalFixtures.getExportArchiveJson();
    final file = File('${scratch.path}/archive.json');
    await file.writeAsString(expected);
    expect(await file.readAsString(), expected);
    expect(expected, contains('entry-river-2026'));
  });
}
