import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import '../timeline/timeline_entry_display.dart';
import '../archive_state_object/archive_state_object.dart';
import '../discover/discover_local.dart';
import '../../storage/mobile_prefs_store.dart';

enum SearchResultType { recording, archiveBelief, discovery }

class SearchResult {
  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.snippet,
    required this.route,
  });

  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String snippet;
  final String route;

  String get typeLabel => switch (type) {
    SearchResultType.recording => 'Recording',
    SearchResultType.archiveBelief => 'Archive Belief',
    SearchResultType.discovery => 'Discovery',
  };
}

class VoiceMemorySearchIndex {
  VoiceMemorySearchIndex({
    required this.entries,
    this.archiveState,
    required this.discoverFeed,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? archiveState;
  final DiscoverLocalFeed discoverFeed;
}

Future<VoiceMemorySearchIndex> buildVoiceMemorySearchIndex({
  required Future<List<JournalEntry>> Function() loadEntries,
  required MobilePrefsStore prefs,
}) async {
  final entries = await loadEntries();
  final baselineRaw = await prefs.discoverBaseline;
  final baseline = baselineRaw?.map((k, v) => MapEntry(k, (v as num).toInt()));
  final feed = DiscoverLocalEngine.build(
    entries: entries,
    baselineThemes: baseline,
  );
  final archive = buildArchiveStateObjectV3(entries: entries);
  return VoiceMemorySearchIndex(
    entries: entries,
    archiveState: archive,
    discoverFeed: feed,
  );
}

List<SearchResult> searchArchiveMe(
  VoiceMemorySearchIndex index,
  String rawQuery,
) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return const [];

  final results = <SearchResult>[];
  final seen = <String>{};

  void add(SearchResult r) {
    if (seen.add(r.id)) results.add(r);
  }

  for (final entry in index.entries) {
    final title = _recordingTitle(entry);
    final tags = _entryTags(entry);
    final searchable = [
      title,
      entry.transcript,
      entry.reflectionSummary,
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      entry.reflection.mood,
      entry.reflection.tensionOrContradiction ?? '',
      entry.reflection.avoidedOrVagueArea ?? '',
      entry.reflection.nextSmallAction ?? '',
      ...entry.reflection.recurringThemes,
      ...entry.reflection.patternObservations,
      ...tags,
    ].join('\n');

    if (_matches(searchable, query)) {
      add(
        SearchResult(
          type: SearchResultType.recording,
          id: 'recording:${entry.id}',
          title: title,
          subtitle: _formatRecordingDate(entry),
          snippet: _bestSnippet(searchable, query, fallback: title),
          route: '/entry/${entry.id}',
        ),
      );
    }
  }

  final archive = index.archiveState;
  if (archive != null) {
    final beliefFields = [
      archive.belief ?? '',
      archive.evidenceSummary ?? '',
      archive.changeSummary,
      archive.watchItem,
      archive.strongestEvidenceQuote ?? '',
    ];
    final beliefText = beliefFields.join('\n');
    if (beliefText.trim().isNotEmpty && _matches(beliefText, query)) {
      add(
        SearchResult(
          type: SearchResultType.archiveBelief,
          id: 'archive-belief',
          title: 'Archive belief',
          subtitle: archive.belief?.trim().isNotEmpty == true
              ? _truncate(archive.belief!, 80)
              : 'Working belief',
          snippet: _bestSnippet(
            beliefText,
            query,
            fallback: archive.changeSummary,
          ),
          route: '/archive-belief',
        ),
      );
    }
  }

  void addDiscoverItems(List<DiscoverChangeItem> items, String section) {
    for (final item in items) {
      final searchable =
          '${item.title}\n${item.detail}\n${item.kind}\n$section';
      if (_matches(searchable, query)) {
        add(
          SearchResult(
            type: SearchResultType.discovery,
            id: 'discovery:${item.kind}:${item.title}',
            title: item.title,
            subtitle: section,
            snippet: _bestSnippet(searchable, query, fallback: item.detail),
            route: '/archive-belief',
          ),
        );
      }
    }
  }

  final feed = index.discoverFeed;
  addDiscoverItems(feed.strengthened, 'Strengthened');
  addDiscoverItems(feed.weakened, 'Weakened');
  addDiscoverItems(feed.newItems, 'New');
  addDiscoverItems(feed.evidenceMovements, 'Evidence');

  results.sort((a, b) {
    final typeOrder = a.type.index.compareTo(b.type.index);
    if (typeOrder != 0) return typeOrder;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return results;
}

bool _matches(String haystack, String query) {
  return haystack.toLowerCase().contains(query);
}

String _recordingTitle(JournalEntry entry) => timelineEntryTitle(entry);

List<String> _entryTags(JournalEntry entry) {
  final tags = <String>[
    ...entry.reflection.recurringThemes,
    if (entry.reflection.mood.isNotEmpty) entry.reflection.mood,
    ...entry.reflection.patternObservations,
  ];
  return tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
}

String _formatRecordingDate(JournalEntry entry) =>
    formatUserFacingDate(entry.createdAt);

String _truncate(String text, int max) {
  if (text.length <= max) return text;
  return '${text.substring(0, max).trim()}…';
}

String _bestSnippet(String text, String query, {required String fallback}) {
  final lower = text.toLowerCase();
  final index = lower.indexOf(query);
  if (index < 0) return _truncate(fallback, 120);
  const window = 48;
  final start = (index - window).clamp(0, text.length);
  final end = (index + query.length + window).clamp(0, text.length);
  var slice = text.substring(start, end).trim();
  if (start > 0) slice = '…$slice';
  if (end < text.length) slice = '$slice…';
  return slice;
}
