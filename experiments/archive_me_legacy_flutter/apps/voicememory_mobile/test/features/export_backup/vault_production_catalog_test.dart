import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/export_backup/export_backup.dart';

void main() {
  test('production catalog maps support vaults into safe namespace', () async {
    final root = await Directory.systemTemp.createTemp('vault_catalog_');
    addTearDown(() => root.delete(recursive: true));
    final documents = Directory('${root.path}/documents')..createSync();
    final support = Directory('${root.path}/support')..createSync();

    final catalog = VaultSourceCatalog.production(
      documents,
      supportRoot: support,
    );

    expect(
      catalog.allows('support/live_audio_vaults/session.vault.enc'),
      isTrue,
    );
    expect(
      catalog.allows('support/live_audio_emergency_chunks/chunk.bin'),
      isTrue,
    );
    expect(
      catalog.allows('support/encrypted_audio_vault/object.m4a.enc'),
      isTrue,
    );
    expect(
      catalog.allows('support/encrypted_audio_vault/object.m4a.enc.partial'),
      isFalse,
    );
    expect(
      catalog.allows('support/encrypted_audio_vault/object.working.m4a'),
      isFalse,
    );
    expect(catalog.allows('support/llm_models/model.bin'), isFalse);
    expect(catalog.allows('mobile_prefs.json'), isFalse);
    expect(catalog.allows('entitlements.json'), isFalse);
    expect(
      catalog
          .destinationFor('support/live_audio_vaults/session.vault.enc')
          .path,
      '${support.path}/live_audio_vaults/session.vault.enc',
    );
    expect(
      catalog.destinationFor('journal_entries.enc').path,
      '${documents.path}/journal_entries.enc',
    );
    expect(
      catalog
          .destinationFor('support/encrypted_audio_vault/object.m4a.enc')
          .path,
      '${support.path}/encrypted_audio_vault/object.m4a.enc',
    );
  });
}
