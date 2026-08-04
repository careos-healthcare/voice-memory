import '../../storage/mobile_prefs_store.dart';
import 'surprise_models.dart';

/// Persists surprise engagement: seen, dismissed, and active card.
class SurpriseStore {
  SurpriseStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _stateKey = 'archiveSurpriseState';

  Future<SurpriseEngagementState> read() async {
    final raw = await _prefs.readJsonMap(_stateKey);
    if (raw == null || raw.isEmpty) return const SurpriseEngagementState();

    final seenRaw = raw['lastSurpriseSeenAt']?.toString();
    final typeName = raw['lastSurpriseType']?.toString();
    final evidence =
        (raw['lastSurpriseEvidence'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    return SurpriseEngagementState(
      lastSurpriseSeenAt: seenRaw != null ? DateTime.tryParse(seenRaw) : null,
      lastSurpriseType: SurpriseType.values.asNameMap()[typeName],
      lastSurpriseEvidence: evidence,
      lastDismissedSurpriseId: raw['lastDismissedSurpriseId']?.toString(),
      activeSurprise: ArchiveSurprise.fromJson(
        raw['activeSurprise'] is Map<String, dynamic>
            ? raw['activeSurprise'] as Map<String, dynamic>
            : raw['activeSurprise'] is Map
            ? Map<String, dynamic>.from(raw['activeSurprise'] as Map)
            : null,
      ),
      lastEntryIdWhenSurprised: raw['lastEntryIdWhenSurprised']?.toString(),
    );
  }

  Future<void> writeActiveSurprise({
    required ArchiveSurprise surprise,
    required String lastEntryId,
  }) async {
    final prior = await read();
    await _write(
      prior.copyWith(
        activeSurprise: surprise,
        lastEntryIdWhenSurprised: lastEntryId,
      ),
    );
  }

  Future<void> markSeen(ArchiveSurprise surprise) async {
    final prior = await read();
    await _write(
      prior.copyWith(
        lastSurpriseSeenAt: DateTime.now(),
        lastSurpriseType: surprise.type,
        lastSurpriseEvidence: surprise.evidenceIds,
      ),
    );
  }

  Future<void> dismiss(ArchiveSurprise surprise) async {
    final prior = await read();
    await _write(
      prior.copyWith(
        lastDismissedSurpriseId: surprise.id,
        clearActiveSurprise: true,
      ),
    );
  }

  Future<void> clearActive() async {
    final prior = await read();
    await _write(prior.copyWith(activeSurprise: null));
  }

  Future<void> _write(SurpriseEngagementState state) async {
    await _prefs.writeJsonMap(_stateKey, {
      if (state.lastSurpriseSeenAt != null)
        'lastSurpriseSeenAt': state.lastSurpriseSeenAt!
            .toUtc()
            .toIso8601String(),
      if (state.lastSurpriseType != null)
        'lastSurpriseType': state.lastSurpriseType!.name,
      'lastSurpriseEvidence': state.lastSurpriseEvidence,
      if (state.lastDismissedSurpriseId != null)
        'lastDismissedSurpriseId': state.lastDismissedSurpriseId,
      if (state.activeSurprise != null)
        'activeSurprise': state.activeSurprise!.toJson(),
      if (state.lastEntryIdWhenSurprised != null)
        'lastEntryIdWhenSurprised': state.lastEntryIdWhenSurprised,
    });
  }
}

extension _SurpriseEngagementCopy on SurpriseEngagementState {
  SurpriseEngagementState copyWith({
    DateTime? lastSurpriseSeenAt,
    SurpriseType? lastSurpriseType,
    List<String>? lastSurpriseEvidence,
    String? lastDismissedSurpriseId,
    ArchiveSurprise? activeSurprise,
    String? lastEntryIdWhenSurprised,
    bool clearActiveSurprise = false,
  }) {
    return SurpriseEngagementState(
      lastSurpriseSeenAt: lastSurpriseSeenAt ?? this.lastSurpriseSeenAt,
      lastSurpriseType: lastSurpriseType ?? this.lastSurpriseType,
      lastSurpriseEvidence: lastSurpriseEvidence ?? this.lastSurpriseEvidence,
      lastDismissedSurpriseId:
          lastDismissedSurpriseId ?? this.lastDismissedSurpriseId,
      activeSurprise: clearActiveSurprise
          ? null
          : (activeSurprise ?? this.activeSurprise),
      lastEntryIdWhenSurprised:
          lastEntryIdWhenSurprised ?? this.lastEntryIdWhenSurprised,
    );
  }
}
