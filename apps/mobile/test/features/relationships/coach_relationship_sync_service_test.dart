import 'dart:io';

import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/coach/coach_client_relationship_store.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/relationships/coach_relationship_sync_service.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('CoachRelationshipSyncService', () {
    late Directory tempDir;
    late UserRelationshipRepository repository;
    late CoachClientRelationshipStore relationshipStore;
    late CoachRelationshipSyncService sync;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('coach_sync_test_');
      final db = await openTestAppSqliteDatabase(filePath: '${tempDir.path}/relationships.db');
      repository = UserRelationshipRepository(db);
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      relationshipStore = CoachClientRelationshipStore(prefs);
      sync = CoachRelationshipSyncService(
        repository: repository,
        relationshipStore: relationshipStore,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('syncFromToken upserts SQLite row from consent token', () async {
      final now = DateTime.now().toUtc();
      final token = CoachConsentToken(
        tokenId: 'token-1',
        relationshipId: 'rel-1',
        clientAccountId: 'client-a',
        coachId: 'coach-b',
        permissions: const CoachSharingPermissions(
          factLedger: true,
          confidenceBandedInsights: true,
          insightKinds: [ArchiveInsightKind.belief],
        ),
        issuedAt: now,
        expiresAt: now.add(const Duration(days: 30)),
        policyVersion: 1,
        clientAffirmationHash: 'hash',
        signature: 'sig',
      );

      final saved = await sync.syncFromToken(
        token,
        clientDisplayName: 'Alex',
      );

      expect(saved.id, 'rel-1');
      expect(saved.clientId, 'client-a');
      expect(saved.professionalId, 'coach-b');
      expect(saved.consentStatus, ConsentStatus.active);
      expect(saved.agreedScope['factLedger'], isTrue);
      expect(saved.agreedScope['clientDisplayName'], 'Alex');

      final sqliteRow = await repository.getById('rel-1');
      expect(sqliteRow, isNotNull);
      expect(sqliteRow!.consentStatus, ConsentStatus.active);

      final prefsRows = await relationshipStore.loadAll();
      expect(prefsRows, hasLength(1));
      expect(prefsRows.single.activeConsentTokenId, 'token-1');
    });
  });
}