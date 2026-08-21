import 'dart:convert';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:drift/drift.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [AccountIdentities, UserRelationships, AccountProStatus])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  static const proStatusSingletonId = 1;

  Future<ProStatusRecord?> loadProStatus() async {
    final row = await (select(accountProStatus)
          ..where((t) => t.id.equals(proStatusSingletonId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _proStatusFromRow(row);
  }

  Future<void> saveProStatus(
    PremiumEntitlements entitlements, {
    required String syncedFrom,
  }) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await into(accountProStatus).insertOnConflictUpdate(
      AccountProStatusCompanion.insert(
        id: Value(proStatusSingletonId),
        isPro: Value(entitlements.isPro ? 1 : 0),
        tier: Value(entitlements.isPro ? 'pro' : 'free'),
        source: Value(entitlements.source),
        entitlementIdsJson: Value(jsonEncode(entitlements.entitlementIds)),
        billingConnected: Value(entitlements.billingConnected ? 1 : 0),
        syncedFrom: Value(syncedFrom),
        updatedAt: nowMillis,
      ),
    );
  }

  Future<void> clearProStatus() async {
    await (delete(accountProStatus)
          ..where((t) => t.id.equals(proStatusSingletonId)))
        .go();
  }

  Future<UserRelationship> requestConnection({
    required UserRelationship relationship,
  }) async {
    final epoch = relationship.createdAt.toUtc().millisecondsSinceEpoch;
    await transaction(() async {
      await _ensureAccountIdentity(relationship.clientId, epoch);
      await _ensureAccountIdentity(relationship.professionalId, epoch);
      await into(userRelationships).insert(_companionFor(relationship));
    });
    return relationship;
  }

  Future<UserRelationship?> updateConsentStatus({
    required String relationshipId,
    required ConsentStatus status,
  }) async {
    final existing = await getRelationshipById(relationshipId);
    if (existing == null) return null;

    final updated = existing.copyWith(
      consentStatus: status,
      updatedAt: DateTime.now().toUtc(),
    );
    await (update(userRelationships)..where((t) => t.id.equals(relationshipId)))
        .write(
      UserRelationshipsCompanion(
        consentStatus: Value(updated.consentStatus.wireValue),
        updatedAt: Value(updated.updatedAt.millisecondsSinceEpoch),
      ),
    );
    return updated;
  }

  Future<UserRelationship?> updateAgreedScope({
    required String relationshipId,
    required Map<String, dynamic> agreedScope,
  }) async {
    final existing = await getRelationshipById(relationshipId);
    if (existing == null) return null;

    final updated = existing.copyWith(
      agreedScope: agreedScope,
      updatedAt: DateTime.now().toUtc(),
    );
    await (update(userRelationships)..where((t) => t.id.equals(relationshipId)))
        .write(
      UserRelationshipsCompanion(
        agreedScope: Value(jsonEncode(updated.agreedScope)),
        updatedAt: Value(updated.updatedAt.millisecondsSinceEpoch),
      ),
    );
    return updated;
  }

  Future<List<UserRelationship>> getActiveProfessionalsForClient(
    String clientId,
  ) async {
    final rows = await (select(userRelationships)
          ..where(
            (t) =>
                t.clientId.equals(clientId) &
                t.relationshipType.equals(RelationshipType.professional.wireValue) &
                t.consentStatus.equals(ConsentStatus.active.wireValue),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_relationshipFromRow).toList();
  }

  Future<List<UserRelationship>> getConsentingClientsForProfessional(
    String professionalId,
  ) async {
    final rows = await (select(userRelationships)
          ..where(
            (t) =>
                t.professionalId.equals(professionalId) &
                t.relationshipType.equals(RelationshipType.professional.wireValue) &
                t.consentStatus.equals(ConsentStatus.active.wireValue),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_relationshipFromRow).toList();
  }

  Future<List<UserRelationship>> listRelationshipsForClient(String clientId) async {
    final rows = await (select(userRelationships)
          ..where((t) => t.clientId.equals(clientId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_relationshipFromRow).toList();
  }

  Future<UserRelationship?> getRelationshipById(String relationshipId) async {
    final row = await (select(userRelationships)
          ..where((t) => t.id.equals(relationshipId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _relationshipFromRow(row);
  }

  Future<UserRelationship> upsertRelationship(UserRelationship relationship) async {
    final now = DateTime.now().toUtc();
    final updated = relationship.copyWith(updatedAt: now);
    final epoch = now.millisecondsSinceEpoch;

    await transaction(() async {
      await _ensureAccountIdentity(updated.clientId, epoch);
      await _ensureAccountIdentity(updated.professionalId, epoch);
      await into(userRelationships).insertOnConflictUpdate(
        _companionFor(updated),
      );
    });
    return updated;
  }

  Future<void> deleteAllRelationshipsForTest() async {
    await delete(userRelationships).go();
    await delete(accountIdentities).go();
  }

  Future<void> _ensureAccountIdentity(String accountId, int createdAt) async {
    await into(accountIdentities).insertOnConflictUpdate(
      AccountIdentitiesCompanion.insert(id: accountId, createdAt: createdAt),
    );
  }

  UserRelationshipsCompanion _companionFor(UserRelationship relationship) {
    return UserRelationshipsCompanion.insert(
      id: relationship.id,
      clientId: relationship.clientId,
      professionalId: relationship.professionalId,
      relationshipType: relationship.relationshipType.wireValue,
      consentStatus: relationship.consentStatus.wireValue,
      agreedScope: Value(jsonEncode(relationship.agreedScope)),
      createdAt: relationship.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAt: relationship.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  UserRelationship _relationshipFromRow(UserRelationshipRow row) {
    Map<String, dynamic> agreedScope = const {};
    try {
      final decoded = jsonDecode(row.agreedScope);
      if (decoded is Map) {
        agreedScope = decoded.map((key, value) => MapEntry('$key', value));
      }
    } on Object {
      agreedScope = const {};
    }

    return UserRelationship(
      id: row.id,
      clientId: row.clientId,
      professionalId: row.professionalId,
      relationshipType: RelationshipTypeWire.fromWire(row.relationshipType) ??
          RelationshipType.professional,
      consentStatus: ConsentStatusWire.fromWire(row.consentStatus) ??
          ConsentStatus.pending,
      agreedScope: agreedScope,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }

  ProStatusRecord _proStatusFromRow(AccountProStatusRow row) {
    List<String> entitlementIds = const [];
    try {
      final decoded = jsonDecode(row.entitlementIdsJson);
      if (decoded is List) {
        entitlementIds = decoded.map((value) => value.toString()).toList();
      }
    } on Object {
      entitlementIds = const [];
    }

    return ProStatusRecord(
      entitlements: PremiumEntitlements(
        tier: row.tier == 'pro' ? BillingTier.pro : BillingTier.free,
        entitlementIds: entitlementIds,
        billingConnected: row.billingConnected != 0,
        source: row.source,
      ),
      syncedFrom: row.syncedFrom,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }
}

/// Local SQLite mirror of the account Pro/Free entitlement snapshot.
class ProStatusRecord {
  const ProStatusRecord({
    required this.entitlements,
    required this.syncedFrom,
    required this.updatedAt,
  });

  final PremiumEntitlements entitlements;
  final String syncedFrom;
  final DateTime updatedAt;
}
