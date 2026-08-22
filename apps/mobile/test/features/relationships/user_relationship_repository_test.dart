import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';
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

  group('UserRelationshipRepository', () {
    late UserRelationshipRepository repository;

    setUp(() async {
      final db = await openTestAppSqliteDatabase();
      repository = UserRelationshipRepository(db);
    });

    test('requestProfessionalConnection creates pending relationship', () async {
      final created = await repository.requestProfessionalConnection(
        clientId: 'client-a',
        professionalId: 'coach-a',
        scope: '{"factLedger":true}',
      );

      expect(created.consentStatus, ConsentStatus.pending);
      expect(created.relationshipType, RelationshipType.professional);
      expect(created.agreedScope['factLedger'], isTrue);
    });

    test('updateConsentStatus activates and lists active professionals', () async {
      final created = await repository.requestProfessionalConnection(
        clientId: 'client-a',
        professionalId: 'coach-a',
        scope: '{}',
      );

      await repository.updateConsentStatus(
        relationshipId: created.id,
        status: ConsentStatus.active,
      );

      final active = await repository.getActiveProfessionalsForClient('client-a');
      expect(active, hasLength(1));
      expect(active.single.professionalId, 'coach-a');

      final clients =
          await repository.getConsentingClientsForProfessional('coach-a');
      expect(clients, hasLength(1));
      expect(clients.single.clientId, 'client-a');
    });
  });
}