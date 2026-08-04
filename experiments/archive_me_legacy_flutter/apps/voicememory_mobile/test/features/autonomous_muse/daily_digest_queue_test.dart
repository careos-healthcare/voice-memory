import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_store.dart';
import 'package:voicememory_mobile/features/autonomous_muse/thematic_triage.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';

void main() {
  test('caps daily actionable cards at 15 and keeps a quiet backlog', () async {
    final root = await Directory.systemTemp.createTemp('daily-digest-');
    final store = AutonomousMuseStore.open(
      databasePath: '${root.path}/muse.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 5)),
      ),
    );
    addTearDown(() async {
      store.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    for (var index = 0; index < 20; index++) {
      store.upsertLegacySuggestion(_suggestion(index));
    }
    final queue = DailyDigestQueue(
      store: store,
      clock: () => DateTime(2026, 7, 29, 8),
    );

    final first = queue.active();
    final second = queue.active();

    expect(first, hasLength(15));
    expect(second.map((item) => item.id), first.map((item) => item.id));
    expect(queue.backlogCount(), 5);
  });
}

LegacyBridgeSuggestion _suggestion(int index) => LegacyBridgeSuggestion(
  id: 'suggestion-$index',
  sourceNodeId: 'source-$index',
  targetNodeId: 'target-$index',
  sourceLabel: 'Source $index',
  targetLabel: 'Target $index',
  entities: const ['Privacy'],
  confidenceScore: .9 - (index / 1000),
  rationale: 'Both notes discuss privacy.',
  sourceExcerpt: 'Source',
  targetExcerpt: 'Target',
  rationaleConfidence: .9,
  createdAt: DateTime.utc(2026, 7, 29),
);
