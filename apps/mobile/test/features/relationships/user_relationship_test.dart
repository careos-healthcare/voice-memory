import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserRelationship round-trips json and map', () {
    final original = UserRelationship(
      id: 'rel-1',
      clientId: 'client-1',
      professionalId: 'coach-1',
      relationshipType: RelationshipType.professional,
      consentStatus: ConsentStatus.pending,
      agreedScope: const {'factLedger': true},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    final fromJson = UserRelationship.fromJson(original.toJson());
    final fromMap = UserRelationship.fromMap(original.toMap());

    expect(fromJson.id, original.id);
    expect(fromJson.agreedScope['factLedger'], isTrue);
    expect(fromMap.consentStatus, ConsentStatus.pending);
  });

  test('copyWith updates consent status', () {
    final relationship = UserRelationship(
      id: 'rel-1',
      clientId: 'client-1',
      professionalId: 'coach-1',
      relationshipType: RelationshipType.professional,
      consentStatus: ConsentStatus.pending,
      agreedScope: const {},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final updated = relationship.copyWith(consentStatus: ConsentStatus.revoked);
    expect(updated.consentStatus, ConsentStatus.revoked);
    expect(updated.id, relationship.id);
  });
}