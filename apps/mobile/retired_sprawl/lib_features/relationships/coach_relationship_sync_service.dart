import 'dart:convert';

import 'package:archiveme_mobile/data/network/user_relationship_api_client.dart';
import 'package:archiveme_mobile/features/coach/coach_client_relationship_store.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';

/// Keeps prefs-based coach relationships, SQLite rows, and server sync aligned.
class CoachRelationshipSyncService {
  CoachRelationshipSyncService({
    required this._repository,
    required this._relationshipStore,
    this._apiClient,
  });

  final UserRelationshipRepository _repository;
  final CoachClientRelationshipStore _relationshipStore;
  final UserRelationshipApiClient? _apiClient;

  /// Migrates legacy prefs relationships into SQLite and pulls server rows.
  Future<void> reconcileOnStartup() async {
    final prefsRows = await _relationshipStore.loadAll();
    for (final coach in prefsRows) {
      await _upsertLocalFromCoach(coach);
    }

    final api = _apiClient;
    if (api == null) return;

    final remote = await api.listForCurrentUser();
    final rows = remote.valueOrNull;
    if (rows == null) return;
    for (final row in rows) {
      await _repository.upsert(row);
    }
  }

  Future<UserRelationship> syncFromCoachRelationship(
    CoachClientRelationship coach,
  ) async {
    await _relationshipStore.save(coach);
    return _upsertLocalFromCoach(coach);
  }

  Future<UserRelationship> syncFromToken(
    CoachConsentToken token, {
    String? clientDisplayName,
    CoachClientRelationshipStatus status =
        CoachClientRelationshipStatus.active,
  }) async {
    final coach = CoachClientRelationship(
      relationshipId: token.relationshipId,
      coachId: token.coachId,
      clientAccountId: token.clientAccountId,
      clientDisplayName: clientDisplayName,
      status: status,
      permissions: token.permissions,
      createdAt: token.issuedAt,
      updatedAt: DateTime.now().toUtc(),
      activeConsentTokenId: token.tokenId,
    );
    return syncFromCoachRelationship(coach);
  }

  Future<void> pushToServer(
    UserRelationship relationship, {
    String? activeConsentTokenId,
  }) async {
    final api = _apiClient;
    if (api == null) return;
    await api.upsert(
      relationship: relationship,
      activeConsentTokenId: activeConsentTokenId,
    );
  }

  Future<UserRelationship> _upsertLocalFromCoach(
    CoachClientRelationship coach,
  ) async {
    final relationship = _toUserRelationship(coach);
    final saved = await _repository.upsert(relationship);
    await pushToServer(
      saved,
      activeConsentTokenId: coach.activeConsentTokenId,
    );
    return saved;
  }

  static UserRelationship _toUserRelationship(
    CoachClientRelationship coach,
  ) {
    return UserRelationship(
      id: coach.relationshipId,
      clientId: coach.clientAccountId,
      professionalId: coach.coachId,
      relationshipType: RelationshipType.professional,
      consentStatus: _mapConsentStatus(coach.status),
      agreedScope: _scopeFromPermissions(
        coach.permissions,
        clientDisplayName: coach.clientDisplayName,
        activeConsentTokenId: coach.activeConsentTokenId,
      ),
      createdAt: coach.createdAt,
      updatedAt: coach.updatedAt,
    );
  }

  static ConsentStatus _mapConsentStatus(
    CoachClientRelationshipStatus status,
  ) {
    return switch (status) {
      CoachClientRelationshipStatus.active => ConsentStatus.active,
      CoachClientRelationshipStatus.revoked ||
      CoachClientRelationshipStatus.expired =>
        ConsentStatus.revoked,
      CoachClientRelationshipStatus.invited ||
      CoachClientRelationshipStatus.consentPending =>
        ConsentStatus.pending,
    };
  }

  static Map<String, dynamic> _scopeFromPermissions(
    CoachSharingPermissions permissions, {
    String? clientDisplayName,
    String? activeConsentTokenId,
  }) {
    return {
      ...permissions.toJson(),
      'clientDisplayName': ?clientDisplayName,
      'activeConsentTokenId': ?activeConsentTokenId,
    };
  }

  static CoachSharingPermissions permissionsFromScope(
    Map<String, dynamic> scope,
  ) {
    final permissionsRaw = <String, dynamic>{};
    for (final entry in scope.entries) {
      if (entry.key == 'clientDisplayName' ||
          entry.key == 'activeConsentTokenId') {
        continue;
      }
      permissionsRaw[entry.key] = entry.value;
    }
    return CoachSharingPermissions.fromJson(permissionsRaw);
  }

  static String? clientDisplayNameFromScope(Map<String, dynamic> scope) =>
      scope['clientDisplayName']?.toString();

  static String? activeConsentTokenIdFromScope(Map<String, dynamic> scope) =>
      scope['activeConsentTokenId']?.toString();

  static String encodeScope(Map<String, dynamic> scope) => jsonEncode(scope);
}