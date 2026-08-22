import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local store for quick feedback on ArchiveMe's output.
///
/// Newest first, capped at [_maxRows], de-duped by id. Kept in its own prefs
/// key so the rest of the schema is untouched.
class ArchiveFeedbackStore {
  ArchiveFeedbackStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveFeedback';
  static const _maxRows = 300;

  static ArchiveFeedbackStore instance() =>
      ArchiveFeedbackStore(AppServices.instance.prefs);

  Future<void> save(ArchiveFeedback feedback) async {
    final all = await loadAll();
    final next = <ArchiveFeedback>[
      feedback,
      ...all.where((f) => f.id != feedback.id),
    ];
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final capped = next.take(_maxRows).toList();
    await _prefs.writeMap(_key, {
      'items': capped.map((f) => f.toJson()).toList(),
    });
  }

  Future<List<ArchiveFeedback>> loadAll() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final rows = <ArchiveFeedback>[];
    for (final e in list) {
      final map = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      final row = ArchiveFeedback.fromJson(map);
      if (row != null) rows.add(row);
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<List<ArchiveFeedback>> loadRecent({int limit = 50}) async {
    final all = await loadAll();
    return all.take(limit).toList();
  }

  Future<List<ArchiveFeedback>> loadForTarget(
    ArchiveFeedbackTargetType targetType,
    String? targetId,
  ) async {
    final all = await loadAll();
    return all.where((f) {
      if (f.targetType != targetType) return false;
      if (targetId == null) return true;
      return f.targetId == targetId;
    }).toList();
  }

  Future<ArchiveFeedbackSummary> summary() async {
    final all = await loadAll();
    return buildArchiveFeedbackSummary(all);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {'items': []});
  }
}