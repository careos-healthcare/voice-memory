import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'signal_feedback_model.dart';

/// Local store for post-save signal feedback events.
class SignalFeedbackStore {
  SignalFeedbackStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'postSaveSignalFeedback';
  static const _maxRows = 200;

  static SignalFeedbackStore instance() =>
      SignalFeedbackStore(AppServices.instance.prefs);

  Future<void> save(PostSaveSignalFeedback feedback) async {
    final all = await loadAll();
    final next = <PostSaveSignalFeedback>[
      feedback,
      ...all.where((f) => f.id != feedback.id),
    ];
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final capped = next.take(_maxRows).toList();
    await _prefs.writeMap(_key, {
      'items': capped.map((f) => f.toJson()).toList(),
    });
  }

  Future<List<PostSaveSignalFeedback>> loadAll() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final rows = <PostSaveSignalFeedback>[];
    for (final e in list) {
      final map = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      final row = PostSaveSignalFeedback.fromJson(map);
      if (row != null) rows.add(row);
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }
}
