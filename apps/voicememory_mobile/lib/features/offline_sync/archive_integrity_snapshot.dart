import '../../models/sync_status.dart';
import '../../services/app_services.dart';
import '../archive_state_object/archive_state_object.dart';

/// Local archive integrity fingerprint for offline sync proof.
class ArchiveIntegritySnapshot {
  ArchiveIntegritySnapshot({
    required this.eligibleCount,
    required this.reflectionTimestamps,
    required this.beliefActive,
    required this.beliefText,
    required this.evidenceCount,
    required this.archiveHealth,
  });

  final int eligibleCount;
  final List<String> reflectionTimestamps;
  final bool beliefActive;
  final String beliefText;
  final int evidenceCount;
  final String archiveHealth;

  Map<String, dynamic> toJson() => {
    'eligibleCount': eligibleCount,
    'reflectionTimestamps': reflectionTimestamps,
    'beliefActive': beliefActive,
    'beliefText': beliefText,
    'evidenceCount': evidenceCount,
    'archiveHealth': archiveHealth,
  };

  factory ArchiveIntegritySnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ArchiveIntegritySnapshot(
        eligibleCount: 0,
        reflectionTimestamps: const [],
        beliefActive: false,
        beliefText: '',
        evidenceCount: 0,
        archiveHealth: '',
      );
    }
    final ts = json['reflectionTimestamps'];
    return ArchiveIntegritySnapshot(
      eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
      reflectionTimestamps: ts is List
          ? ts.map((e) => e.toString()).toList()
          : const [],
      beliefActive: json['beliefActive'] == true,
      beliefText: json['beliefText']?.toString() ?? '',
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      archiveHealth: json['archiveHealth']?.toString() ?? '',
    );
  }

  static Future<ArchiveIntegritySnapshot> capture() async {
    final journal = AppServices.instance.journal;
    final entries = await journal.loadAll();
    final eligible = await journal.loadEligible();
    final state = buildArchiveStateObjectV3(entries: entries);

    final timestamps =
        eligible.map((e) => e.createdAt.toUtc().toIso8601String()).toList()
          ..sort();

    return ArchiveIntegritySnapshot(
      eligibleCount: eligible.length,
      reflectionTimestamps: timestamps,
      beliefActive: state?.hasMinimumEvidence ?? false,
      beliefText: state?.belief ?? '',
      evidenceCount: state?.evidenceReflectionCount ?? 0,
      archiveHealth: state != null ? healthLabel(state.health) : '',
    );
  }

  bool timestampsMatch(ArchiveIntegritySnapshot other) {
    if (reflectionTimestamps.length != other.reflectionTimestamps.length) {
      return false;
    }
    for (var i = 0; i < reflectionTimestamps.length; i++) {
      if (reflectionTimestamps[i] != other.reflectionTimestamps[i]) {
        return false;
      }
    }
    return true;
  }

  bool beliefPreservedComparedTo(ArchiveIntegritySnapshot other) {
    return beliefActive == other.beliefActive && beliefText == other.beliefText;
  }

  bool evidencePreservedComparedTo(ArchiveIntegritySnapshot other) {
    return evidenceCount == other.evidenceCount;
  }

  /// Entries from baseline timestamps that are now synced.
  Future<int> countSyncedFromBaseline(List<String> baselineTimestamps) async {
    if (baselineTimestamps.isEmpty) return 0;
    final set = baselineTimestamps.toSet();
    final all = await AppServices.instance.journal.loadAll();
    var synced = 0;
    for (final e in all) {
      final iso = e.createdAt.toUtc().toIso8601String();
      if (set.contains(iso) && e.syncStatus == SyncStatus.synced) {
        synced += 1;
      }
    }
    return synced;
  }
}
