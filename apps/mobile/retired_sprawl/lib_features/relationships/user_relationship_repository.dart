import 'dart:convert';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:uuid/uuid.dart';

/// SQLite-backed CRUD for unified client ↔ professional relationships.
class UserRelationshipRepository {
  UserRelationshipRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;

  AppDatabase get _db => _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  Future<UserRelationship> requestProfessionalConnection({
    required String clientId,
    required String professionalId,
    required String scope,
  }) async {
    return requestConnection(
      clientId: clientId,
      professionalId: professionalId,
      relationshipType: RelationshipType.professional,
      scope: scope,
    );
  }

  Future<UserRelationship> requestConnection({
    required String clientId,
    required String professionalId,
    required RelationshipType relationshipType,
    required String scope,
  }) async {
    final now = DateTime.now().toUtc();
    final relationship = UserRelationship(
      id: const Uuid().v4(),
      clientId: clientId,
      professionalId: professionalId,
      relationshipType: relationshipType,
      consentStatus: ConsentStatus.pending,
      agreedScope: _parseScopeJson(scope),
      createdAt: now,
      updatedAt: now,
    );

    return _db.accountDao.requestConnection(relationship: relationship);
  }

  Future<UserRelationship?> updateConsentStatus({
    required String relationshipId,
    required ConsentStatus status,
  }) =>
      _db.accountDao.updateConsentStatus(
        relationshipId: relationshipId,
        status: status,
      );

  Future<UserRelationship?> updateAgreedScope({
    required String relationshipId,
    required Map<String, dynamic> agreedScope,
  }) =>
      _db.accountDao.updateAgreedScope(
        relationshipId: relationshipId,
        agreedScope: agreedScope,
      );

  Future<List<UserRelationship>> getActiveProfessionalsForClient(
    String clientId,
  ) =>
      _db.accountDao.getActiveProfessionalsForClient(clientId);

  Future<List<UserRelationship>> getConsentingClientsForProfessional(
    String professionalId,
  ) =>
      _db.accountDao.getConsentingClientsForProfessional(professionalId);

  Future<List<UserRelationship>> listForClient(String clientId) =>
      _db.accountDao.listRelationshipsForClient(clientId);

  Future<UserRelationship?> getById(String relationshipId) =>
      _db.accountDao.getRelationshipById(relationshipId);

  Future<UserRelationship> upsert(UserRelationship relationship) =>
      _db.accountDao.upsertRelationship(relationship);

  Future<void> deleteAllForTest() => _db.accountDao.deleteAllRelationshipsForTest();

  static Map<String, dynamic> _parseScopeJson(String scope) {
    if (scope.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(scope);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
    }
    return {'rawScope': scope};
  }
}
