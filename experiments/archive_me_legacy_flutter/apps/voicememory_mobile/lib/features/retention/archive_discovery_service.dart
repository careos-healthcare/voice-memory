import 'dart:convert';

import '../../models/journal_entry.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../belief_shift/belief_shift_engine.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../discover/chapter_engine.dart';
import '../discover/theme_engine.dart';

/// Proactive discovery surfaced on Archive / Discover return triggers.
class ArchiveDiscoveryNotice {
  const ArchiveDiscoveryNotice({
    required this.id,
    required this.headline,
    required this.detail,
    required this.detectedAt,
    required this.kind,
  });

  final String id;
  final String headline;
  final String detail;
  final DateTime detectedAt;
  final ArchiveDiscoveryKind kind;
}

enum ArchiveDiscoveryKind {
  newBelief,
  newContradiction,
  themeIncreased,
  chapterChanged,
}

class ArchiveDiscoveryService {
  ArchiveDiscoveryService(this._prefs);

  final MobilePrefsStore _prefs;

  static const _lastViewedKey = 'lastViewedDiscoveryTimestamp';
  static const _fingerprintKey = 'lastDiscoveryFingerprint';

  Future<DateTime?> readLastViewedAt() async {
    final raw = await _prefs.readString(_lastViewedKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markDiscoveryViewed(DateTime at) async {
    await _prefs.writeString(_lastViewedKey, at.toUtc().toIso8601String());
  }

  Future<String?> _readStoredFingerprint() async =>
      _prefs.readString(_fingerprintKey);

  Future<void> _writeFingerprint(String fp) async =>
      _prefs.writeString(_fingerprintKey, fp);

  /// Latest notice if newer than [lastViewedAt] and fingerprint changed.
  ArchiveDiscoveryNotice? detectNotice({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    required DateTime? lastViewedAt,
    String? storedFingerprint,
  }) {
    if (entries.length < 2) return null;

    final notice = _buildNotice(entries, state);
    if (notice == null) return null;

    final fp = _fingerprint(entries, state);
    if (storedFingerprint != null && storedFingerprint == fp) {
      if (lastViewedAt != null && !notice.detectedAt.isAfter(lastViewedAt)) {
        return null;
      }
    }

    if (lastViewedAt != null && !notice.detectedAt.isAfter(lastViewedAt)) {
      return null;
    }

    return notice;
  }

  Future<ArchiveDiscoveryNotice?> loadActiveNotice({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) async {
    final lastViewed = await readLastViewedAt();
    final storedFp = await _readStoredFingerprint();
    final fp = _fingerprint(entries, state);
    final notice = _buildNotice(entries, state);
    if (notice == null) return null;

    if (storedFp == fp &&
        lastViewed != null &&
        !notice.detectedAt.isAfter(lastViewed)) {
      return null;
    }

    if (lastViewed != null &&
        storedFp == fp &&
        notice.detectedAt.isBefore(lastViewed)) {
      return null;
    }

    return notice;
  }

  Future<void> acknowledgeDiscovery({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    required DateTime viewedAt,
  }) async {
    await markDiscoveryViewed(viewedAt);
    await _writeFingerprint(_fingerprint(entries, state));
  }

  ArchiveDiscoveryNotice? _buildNotice(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final now = entries.last.createdAt;
    final belief =
        state?.belief?.trim() ?? archiveBeliefFromReflections(entries)?.trim();

    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    if (contradictions.reports.isNotEmpty) {
      final top = contradictions.reports.first;
      return ArchiveDiscoveryNotice(
        id: 'contradiction:${top.id}',
        headline: 'Something worth noticing',
        detail:
            'Two moments pull in different directions about the same theme.',
        detectedAt: now,
        kind: ArchiveDiscoveryKind.newContradiction,
      );
    }

    final shifts = const BeliefShiftEngine().detect(
      entries: entries,
      currentBelief: belief,
    );
    if (shifts.reports.isNotEmpty) {
      final top = shifts.reports.first;
      return ArchiveDiscoveryNotice(
        id: 'pattern-shift:${top.id}',
        headline: 'Something worth noticing',
        detail:
            'A pattern may be shifting: “${top.newBelief.length > 80 ? '${top.newBelief.substring(0, 80)}…' : top.newBelief}”.',
        detectedAt: now,
        kind: ArchiveDiscoveryKind.newBelief,
      );
    }

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeek = entries
        .where((e) => e.createdAt.isAfter(weekAgo))
        .toList();
    final prior = entries.where((e) => !e.createdAt.isAfter(weekAgo)).toList();
    if (thisWeek.length >= 2) {
      final current = DiscoverLocalThemeCounts.count(thisWeek);
      final baseline = DiscoverLocalThemeCounts.count(prior);
      String? topTheme;
      var topDelta = 0;
      for (final e in current.entries) {
        final delta = e.value - (baseline[e.key] ?? 0);
        if (delta > topDelta) {
          topDelta = delta;
          topTheme = e.key;
        }
      }
      if (topTheme != null && topDelta >= 2) {
        final label = _themeLabel(topTheme);
        return ArchiveDiscoveryNotice(
          id: 'theme:$topTheme:$topDelta',
          headline: 'Something worth noticing',
          detail: 'You mentioned $label ${current[topTheme]} times this week.',
          detectedAt: now,
          kind: ArchiveDiscoveryKind.themeIncreased,
        );
      }
    }

    final chapters = const DiscoverChapterEngine().build(entries);
    if (chapters.length >= 2) {
      final latest = chapters.last;
      return ArchiveDiscoveryNotice(
        id: 'chapter:${latest.id}',
        headline: 'Something worth noticing',
        detail: 'Life chapter updated: “${latest.title}”.',
        detectedAt: latest.endDate,
        kind: ArchiveDiscoveryKind.chapterChanged,
      );
    }

    if (belief != null &&
        belief.isNotEmpty &&
        archiveHasMinimumEvidence(entries)) {
      return ArchiveDiscoveryNotice(
        id: 'pattern:${belief.hashCode}',
        headline: 'Something worth noticing',
        detail:
            'A pattern may be forming: “${belief.length > 90 ? '${belief.substring(0, 90)}…' : belief}”.',
        detectedAt: now,
        kind: ArchiveDiscoveryKind.newBelief,
      );
    }

    return null;
  }

  String _fingerprint(List<JournalEntry> entries, ArchiveStateObjectV3? state) {
    final belief = state?.belief ?? '';
    final themes = DiscoverLocalThemeCounts.count(entries);
    final chapters = const DiscoverChapterEngine().build(entries);
    final payload = {
      'belief': belief,
      'themes': themes,
      'chapterIds': chapters.map((c) => c.id).toList(),
      'count': entries.length,
      'lastId': entries.isNotEmpty ? entries.last.id : '',
    };
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }

  static String _themeLabel(String key) {
    const labels = {
      'career': 'career',
      'work': 'work',
      'confidence': 'confidence',
      'relationship': 'relationships',
      'relationships': 'relationships',
      'health': 'health',
      'family': 'family',
      'stress': 'stress',
      'money': 'money',
      'purpose': 'purpose',
    };
    return labels[key] ?? key;
  }
}
