import '../../storage/mobile_prefs_store.dart';

enum ArchiveTimelineTruthFeedback {
  yes,
  partly,
  notReally;

  String get storageId => switch (this) {
    yes => 'yes',
    partly => 'partly',
    notReally => 'notReally',
  };

  static ArchiveTimelineTruthFeedback? fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in ArchiveTimelineTruthFeedback.values) {
      if (value.storageId == raw) return value;
    }
    return null;
  }
}

class ArchiveTimelineTruthMetrics {
  const ArchiveTimelineTruthMetrics({
    required this.promptTappedCount,
    required this.timelineViewed,
    required this.timelineExpanded,
    this.truthFeedback,
    this.truthFeedbackNote,
  });

  final int promptTappedCount;
  final bool timelineViewed;
  final bool timelineExpanded;
  final ArchiveTimelineTruthFeedback? truthFeedback;
  final String? truthFeedbackNote;

  bool get hasTruthFeedback => truthFeedback != null;
}

/// Optional beta/debug metrics for change timeline and truth feedback.
class ArchiveChangeTimelineMetricsStore {
  ArchiveChangeTimelineMetricsStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'archiveChangeTimelineMetrics';

  Future<ArchiveTimelineTruthMetrics> load() async {
    final map = await _prefs.readMap(_key) ?? {};
    return ArchiveTimelineTruthMetrics(
      promptTappedCount: _readCount(map['promptTappedCount']),
      timelineViewed: map['archiveTimelineViewed'] == true,
      timelineExpanded: map['archiveTimelineExpanded'] == true,
      truthFeedback: ArchiveTimelineTruthFeedback.fromStorage(
        map['archiveTimelineTruthFeedback']?.toString(),
      ),
      truthFeedbackNote: map['archiveTimelineTruthFeedbackNote']?.toString(),
    );
  }

  Future<int> promptTappedCount() async {
    return (await load()).promptTappedCount;
  }

  Future<void> incrementPromptTap() async {
    final map = await _prefs.readMap(_key) ?? {};
    final next = _readCount(map['promptTappedCount']) + 1;
    await _prefs.writeMap(_key, {...map, 'promptTappedCount': next});
  }

  Future<void> markTimelineViewed() async {
    final map = await _prefs.readMap(_key) ?? {};
    if (map['archiveTimelineViewed'] == true) return;
    await _prefs.writeMap(_key, {...map, 'archiveTimelineViewed': true});
  }

  Future<void> markTimelineExpanded() async {
    final map = await _prefs.readMap(_key) ?? {};
    await _prefs.writeMap(_key, {...map, 'archiveTimelineExpanded': true});
  }

  Future<void> saveTruthFeedback({
    required ArchiveTimelineTruthFeedback feedback,
    String? note,
  }) async {
    final map = await _prefs.readMap(_key) ?? {};
    await _prefs.writeMap(_key, {
      ...map,
      'archiveTimelineTruthFeedback': feedback.storageId,
      if (note != null && note.trim().isNotEmpty)
        'archiveTimelineTruthFeedbackNote': note.trim(),
    });
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  int _readCount(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
