/// Day 2 Return Preview — a lightweight, passive preview of what ArchiveMe
/// will check tomorrow, shown right after the first save to make the reason
/// to come back feel specific.
///
/// Privacy by construction: the body is assembled only from a fixed
/// whitelist of safe context labels. Raw notes, transcripts, evidence
/// snippets, and belief phrases can never reach the copy — unknown tag ids
/// simply fall back to the generic line.
class DayTwoReturnPreview {
  const DayTwoReturnPreview({required this.show, this.body = ''});

  factory DayTwoReturnPreview.none() => const DayTwoReturnPreview(show: false);

  final bool show;
  final String body;

  static const String title = 'Tomorrow, check this';

  /// Exactly one safe context tag — names the thread with its safe label.
  static String singleContextBody(String label) =>
      'ArchiveMe will check whether the $label thread returned, faded, or '
      'changed.';

  /// Multiple safe contexts — one thread reference, no label picking.
  static const String multiContextBody =
      'ArchiveMe will check whether this thread returned, faded, or changed.';

  /// No safe label — never guesses, never quotes.
  static const String genericBody =
      'ArchiveMe will check whether this returned, faded, or changed.';

  static const String smallLine = 'One check is enough.';
}

/// Pure, deterministic preview builder. No AI, no stored state, no streaks —
/// built only from the entry count, saved entry dates, and context tag ids.
class DayTwoReturnPreviewEngine {
  const DayTwoReturnPreviewEngine();

  /// The only labels that may ever appear in the preview body. Tag ids
  /// outside this list (including anything user-shaped) are ignored.
  static const Set<String> safeContextIds = {
    'work',
    'family',
    'money',
    'health',
    'stopping',
    'deadline',
    'people',
    'energy',
  };

  /// Hidden once the archive holds this many entries — the loop is running.
  static const int hiddenEntryCount = 3;

  /// - 0 entries → nothing; the preview exists only after the first save.
  /// - 3+ entries → nothing; the loop is already running.
  /// - Entries on 2+ distinct days → nothing; the day-2 return moment
  ///   already happened.
  /// - Otherwise → the preview, with the most specific body the safe
  ///   labels allow.
  DayTwoReturnPreview build({
    required int entryCount,
    List<String> contextTagIds = const [],
    List<DateTime> entryDates = const [],
    DateTime? now,
  }) {
    if (entryCount < 1 || entryCount >= hiddenEntryCount) {
      return DayTwoReturnPreview.none();
    }

    final clock = now ?? DateTime.now();
    final datesReliable =
        entryDates.isNotEmpty && !entryDates.any((d) => d.isAfter(clock));
    if (datesReliable) {
      final days = entryDates
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet();
      if (days.length >= 2) {
        // Recorded on two different days — the return moment happened.
        return DayTwoReturnPreview.none();
      }
    }

    final safe = contextTagIds.where(safeContextIds.contains).toSet();
    if (safe.length == 1) {
      return DayTwoReturnPreview(
        show: true,
        body: DayTwoReturnPreview.singleContextBody(safe.single),
      );
    }
    if (safe.length > 1) {
      return const DayTwoReturnPreview(
        show: true,
        body: DayTwoReturnPreview.multiContextBody,
      );
    }
    return const DayTwoReturnPreview(
      show: true,
      body: DayTwoReturnPreview.genericBody,
    );
  }
}