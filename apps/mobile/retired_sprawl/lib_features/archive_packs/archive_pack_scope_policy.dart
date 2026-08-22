import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:flutter/foundation.dart';

/// Pack-scoped memory rules — memory prefers same-pack evidence and
/// blocks cross-pack connections unless explicitly allowed.
abstract class ArchivePackScopePolicy {
  ArchivePackScopePolicy._();

  static final Map<String, bool> _allowCrossByPackId = <String, bool>{};

  static void applyLoadedPacks(Iterable<ArchivePack> packs) {
    _allowCrossByPackId
      ..clear()
      ..addAll({for (final p in packs) p.id: p.allowCrossPackConnections});
  }

  @visibleForTesting
  static void resetForTest() {
    _allowCrossByPackId.clear();
  }

  static bool packAllowsCrossConnections(String packId) =>
      _allowCrossByPackId[packId] ?? false;

  static bool isCrossPack(List<PressureCheckInRecord> records) {
    final packIds = records
        .map((r) => r.archivePackId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return packIds.length >= 2;
  }

  static bool allowsCrossPackByPolicy(List<PressureCheckInRecord> records) {
    if (!isCrossPack(records)) return true;
    final packIds = records
        .map((r) => r.archivePackId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in packIds) {
      if (packAllowsCrossConnections(id)) return true;
    }
    return false;
  }

  static String? primaryPackId(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final r in records) {
      final id = r.archivePackId;
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Filters to same-pack evidence when cross-pack is not allowed.
  static List<PressureCheckInRecord> filterSamePackPreferred(
    List<PressureCheckInRecord> records, {
    required bool crossPackAllowed,
  }) {
    if (crossPackAllowed || !isCrossPack(records)) return records;
    final anchor = primaryPackId(records);
    if (anchor == null) return records;
    return records
        .where(
          (r) =>
              r.archivePackId == null ||
              r.archivePackId!.isEmpty ||
              r.archivePackId == anchor,
        )
        .toList();
  }

  /// Instructions are never connection evidence.
  static bool isInstructionsEvidence(String? _) => false;
}