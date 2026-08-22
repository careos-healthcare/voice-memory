import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists coach-client relationships for the active account namespace.
class CoachClientRelationshipStore {
  CoachClientRelationshipStore(this._prefs);

  static const prefsKey = 'coach_client_relationships_v1';

  final MobilePrefsStore _prefs;

  Future<List<CoachClientRelationship>> loadAll() async {
    final raw = await _prefs.readMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    return raw.values
        .whereType<Map>()
        .map((value) => CoachClientRelationship.fromJson(
              Map<String, dynamic>.from(value),
            ))
        .toList();
  }

  Future<CoachClientRelationship?> getById(String relationshipId) async {
    final raw = await _prefs.readMap(prefsKey);
    final value = raw?[relationshipId];
    if (value is! Map) return null;
    return CoachClientRelationship.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> save(CoachClientRelationship relationship) async {
    final raw = await _prefs.readMap(prefsKey) ?? {};
    raw[relationship.relationshipId] = relationship.toJson();
    await _prefs.writeMap(prefsKey, raw);
  }

  Future<void> resetForTest() async {
    await _prefs.writeMap(prefsKey, {});
  }
}