import '../../storage/mobile_prefs_store.dart';

class ArchiveStateSnapshot {
  ArchiveStateSnapshot({
    required this.belief,
    required this.confidence,
    required this.reputation,
    required this.evidenceCount,
    required this.lifeAreas,
    required this.timestamp,
  });

  final String belief;
  final int confidence;
  final String reputation;
  final int evidenceCount;
  final List<String> lifeAreas;
  final String timestamp;

  Map<String, dynamic> toJson() => {
        'belief': belief,
        'confidence': confidence,
        'reputation': reputation,
        'evidenceCount': evidenceCount,
        'lifeAreas': lifeAreas,
        'timestamp': timestamp,
      };

  static ArchiveStateSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final belief = json['belief'];
    if (belief is! String) return null;
    return ArchiveStateSnapshot(
      belief: belief,
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      reputation: json['reputation']?.toString() ?? 'low',
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      lifeAreas: (json['lifeAreas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class ArchiveStateDeltaRow {
  ArchiveStateDeltaRow({
    required this.label,
    required this.then,
    required this.now,
    required this.difference,
  });

  final String label;
  final String then;
  final String now;
  final String difference;
}

class ArchiveStateDeltaView {
  ArchiveStateDeltaView({
    required this.hasChanges,
    required this.rows,
    required this.headline,
    this.subheadline,
    required this.awayReturn,
  });

  final bool hasChanges;
  final List<ArchiveStateDeltaRow> rows;
  final String headline;
  final String? subheadline;
  final bool awayReturn;
}

class ArchiveStateSnapshotStore {
  ArchiveStateSnapshotStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _snapshotKey = 'archiveStateSnapshot';
  static const _lastViewKey = 'archiveLastViewAt';

  Future<ArchiveStateSnapshot?> readSnapshot() async {
    final raw = await _prefs.readJsonMap(_snapshotKey);
    return ArchiveStateSnapshot.fromJson(raw);
  }

  Future<void> writeSnapshot(ArchiveStateSnapshot snapshot) async {
    await _prefs.writeJsonMap(_snapshotKey, snapshot.toJson());
    await _prefs.writeString(_lastViewKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> readLastViewAt() async {
    final raw = await _prefs.readString(_lastViewKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}

/// Lightweight mobile delta from reflection count + reputation label.
ArchiveStateDeltaView? buildMobileArchiveStateDelta({
  required int reflectionCount,
  required String? reputationLabel,
  required ArchiveStateSnapshot? baseline,
  required DateTime? lastViewAt,
}) {
  if (reflectionCount < 2) return null;

  final away = lastViewAt != null &&
      DateTime.now().difference(lastViewAt).inDays >= 3;

  if (baseline == null) {
    return ArchiveStateDeltaView(
      hasChanges: false,
      rows: [],
      headline: 'What changed since you last looked',
      subheadline: 'Your next visit will show what changed.',
      awayReturn: false,
    );
  }

  final rows = <ArchiveStateDeltaRow>[];
  final nowRep = reputationLabel ?? 'Developing';
  if (baseline.reputation != nowRep) {
    rows.add(ArchiveStateDeltaRow(
      label: 'Reputation',
      then: _titleCase(baseline.reputation),
      now: nowRep,
      difference: '${_titleCase(baseline.reputation)} → $nowRep',
    ));
  }

  if (reflectionCount != baseline.evidenceCount) {
    rows.add(ArchiveStateDeltaRow(
      label: 'Evidence',
      then: '${baseline.evidenceCount}',
      now: '$reflectionCount',
      difference: '${baseline.evidenceCount} → $reflectionCount',
    ));
  }

  if (rows.isEmpty && !away) {
    return ArchiveStateDeltaView(
      hasChanges: false,
      rows: [],
      headline: 'What changed since you last looked',
      subheadline: 'No archive movement since your last visit.',
      awayReturn: false,
    );
  }

  return ArchiveStateDeltaView(
    hasChanges: rows.isNotEmpty,
    rows: rows,
    headline: away
        ? 'Your archive changed while you were away.'
        : 'What changed since you last looked',
    awayReturn: away,
  );
}

ArchiveStateSnapshot snapshotFromMobile({
  required int reflectionCount,
  required String beliefText,
  required String reputation,
}) {
  return ArchiveStateSnapshot(
    belief: beliefText,
    confidence: reflectionCount >= 5 ? 72 : 40,
    reputation: reputation,
    evidenceCount: reflectionCount,
    lifeAreas: const [],
    timestamp: DateTime.now().toIso8601String(),
  );
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}
