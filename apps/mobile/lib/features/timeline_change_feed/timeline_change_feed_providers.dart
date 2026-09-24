import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Year and month chips. A null year means the whole archive.
class TimelineDateRange {
  const TimelineDateRange({this.year, this.month});

  final int? year;
  final int? month;
}

class TimelineDateRangeNotifier extends Notifier<TimelineDateRange> {
  @override
  TimelineDateRange build() => const TimelineDateRange();

  void selectYear(int? year) {
    state = TimelineDateRange(year: year);
  }

  void selectMonth(int? month) {
    state = TimelineDateRange(year: state.year, month: month);
  }
}

final timelineDateRangeProvider =
    NotifierProvider<TimelineDateRangeNotifier, TimelineDateRange>(
      TimelineDateRangeNotifier.new,
    );

/// Months the person has collapsed. Missing keys stay open.
class TimelineSectionExpansion {
  const TimelineSectionExpansion({this.collapsed = const {}});

  final Set<String> collapsed;

  bool isExpanded(String storageKey) => !collapsed.contains(storageKey);
}

class TimelineSectionExpansionNotifier
    extends Notifier<TimelineSectionExpansion> {
  @override
  TimelineSectionExpansion build() => const TimelineSectionExpansion();

  void toggle(String storageKey) {
    final next = {...state.collapsed};
    if (!next.add(storageKey)) next.remove(storageKey);
    state = TimelineSectionExpansion(collapsed: next);
  }
}

final timelineSectionExpansionProvider =
    NotifierProvider<
      TimelineSectionExpansionNotifier,
      TimelineSectionExpansion
    >(
      TimelineSectionExpansionNotifier.new,
    );

/// Loads the archive the feed groups. The sqlite factory reads the journal mirror.
class TimelineArchiveSource {
  const TimelineArchiveSource(this.loadActive);

  factory TimelineArchiveSource.sqlite(JournalSqliteRepository repository) {
    return TimelineArchiveSource(repository.fetchAllActive);
  }

  final Future<List<JournalEntry>> Function() loadActive;
}

final timelineArchiveSourceProvider = Provider<TimelineArchiveSource>(
  (ref) => TimelineArchiveSource(() async => const []),
);

class TimelineEntriesNotifier extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() {
    return ref.watch(timelineArchiveSourceProvider).loadActive();
  }
}

final timelineEntriesProvider =
    AsyncNotifierProvider<TimelineEntriesNotifier, List<JournalEntry>>(
      TimelineEntriesNotifier.new,
    );
