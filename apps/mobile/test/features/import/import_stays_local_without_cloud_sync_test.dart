import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('import stays on device when cloud sync is off', () async {
    final client = MockClient((request) async {
      fail('imported entries must not be posted while cloud sync is off');
    });
    final service = BacklogImportService(HttpTransport(client: client));
    final saved = <String>[];

    final progress = await service.uploadQueue(
      [
        BacklogImportChunk(
          entryId: 'note-1',
          sourceFile: 'notes.txt',
          kind: BacklogImportChunkKind.text,
          rawText: 'a walk by the river',
        ),
      ],
      cloudSyncEnabled: false,
      saveLocally: (chunk) async => saved.add(chunk.entryId),
    );

    expect(progress.phase, BacklogImportPhase.complete);
    expect(progress.statusMessage, 'Saved on this device.');
    expect(saved, ['note-1']);
    expect(progress.importedCount, 1);
  });
}
