import 'tomorrow_commitment_model.dart';
import 'watch_for_model.dart';
import 'active_pattern_thread_model.dart';

/// Builds and updates named active pattern threads from watch-for outcomes.
class ActivePatternThreadEngine {
  const ActivePatternThreadEngine();

  String titleFromWatchFor(String watchForText) {
    var phrase = watchForText.trim();
    if (phrase.startsWith('whether ')) {
      phrase = phrase.substring(8).trim();
    }
    if (phrase.isEmpty) return 'A pattern you are watching';

    if (phrase.startsWith('you ')) {
      final rest = phrase.substring(4).trim();
      if (rest.startsWith('take ')) {
        return 'Taking ${rest.substring(5)}';
      }
      if (rest.isNotEmpty) {
        return 'Taking $rest';
      }
    }

    if (phrase.startsWith('the same ')) {
      var rest = phrase.substring(9).trim();
      if (rest.endsWith('shows up again')) {
        rest = '${rest.substring(0, rest.length - 'shows up again'.length).trim()} returning';
      }
      if (rest.isNotEmpty) {
        return 'The same $rest';
      }
    }

    if (phrase.endsWith(' shows up again')) {
      phrase =
          '${phrase.substring(0, phrase.length - ' shows up again'.length).trim()} returning';
    }

    return phrase[0].toUpperCase() + phrase.substring(1);
  }

  ActivePatternThreadStatus statusFromRecentResults(List<WatchForResult> recent) {
    if (recent.isEmpty) return ActivePatternThreadStatus.active;
    final last = recent.first;
    if (last == WatchForResult.changedShape) {
      return ActivePatternThreadStatus.changing;
    }
    if (recent.length >= 2 &&
        recent[0] == WatchForResult.didNotShow &&
        recent[1] == WatchForResult.didNotShow) {
      return ActivePatternThreadStatus.easing;
    }
    if (last == WatchForResult.unclear) {
      return ActivePatternThreadStatus.active;
    }
    if (last == WatchForResult.didNotShow && recent.length == 1) {
      return ActivePatternThreadStatus.active;
    }
    return ActivePatternThreadStatus.active;
  }

  String nextPromptFor({
    required ActivePatternThreadStatus status,
    required String watchForText,
    required bool needsOneMoreMoment,
  }) {
    if (needsOneMoreMoment) {
      return 'Today, add one more moment so ArchiveMe can compare this pattern.';
    }
    switch (status) {
      case ActivePatternThreadStatus.easing:
        return 'Today, notice whether this is still quieter.';
      case ActivePatternThreadStatus.changing:
        return 'Today, notice what feels different about it.';
      case ActivePatternThreadStatus.paused:
        return 'When you are ready, notice whether this pattern returns.';
      case ActivePatternThreadStatus.active:
        final watch = watchForText.trim();
        if (watch.startsWith('whether ')) {
          return 'Today, notice $watch';
        }
        return 'Today, notice whether this shows up again.';
    }
  }

  String lastResultSummary(WatchForResult result) {
    switch (result) {
      case WatchForResult.showedAgain:
        return 'It showed up again.';
      case WatchForResult.didNotShow:
        return 'It did not show up today.';
      case WatchForResult.changedShape:
        return 'It changed shape.';
      case WatchForResult.unclear:
        return 'Needs one more moment.';
      case WatchForResult.none:
        return 'Not checked yet.';
    }
  }

  ActivePatternThread buildFromWatchForResult({
    required WatchForItem completed,
    ActivePatternThread? existing,
    String? momentSnippet,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final result = completed.result;
    final watchText = completed.text.trim();

    final priorResults = existing?.recentResults ?? const <WatchForResult>[];
    final recentResults = [
      result,
      ...priorResults.where((r) => r != WatchForResult.none),
    ].take(5).toList();

    final status = statusFromRecentResults(recentResults);
    final needsMoment = result == WatchForResult.unclear;
    final nextPrompt = nextPromptFor(
      status: status,
      watchForText: watchText,
      needsOneMoreMoment: needsMoment,
    );

    final priorMoments = existing?.recentMoments ?? const <String>[];
    final moments = <String>[
      if (momentSnippet != null && momentSnippet.trim().isNotEmpty)
        _clip(momentSnippet.trim(), 96),
      ...priorMoments,
    ].take(5).toList();

    final today = TomorrowCommitment.dateOnly(clock);
    var daysActive = existing?.daysActive ?? 0;
    if (existing == null) {
      daysActive = 1;
    } else {
      final lastDay = existing.lastResultDate != null
          ? TomorrowCommitment.dateOnly(existing.lastResultDate!)
          : null;
      if (lastDay == null || lastDay != today) {
        daysActive += 1;
      }
    }

    return ActivePatternThread(
      id: existing?.id ?? 'thread_${clock.microsecondsSinceEpoch}',
      title: existing?.title ?? titleFromWatchFor(watchText),
      createdAt: existing?.createdAt ?? clock,
      updatedAt: clock,
      watchForText: watchText,
      chips: completed.chips.take(3).toList(),
      status: status,
      daysActive: daysActive,
      lastResult: result,
      lastResultDate: clock,
      recentMoments: moments,
      recentResults: recentResults,
      nextPrompt: nextPrompt,
    );
  }

  bool shouldCompleteAsInactive(ActivePatternThread thread, {DateTime? now}) {
    if (thread.status != ActivePatternThreadStatus.easing) return false;
    final clock = now ?? DateTime.now();
    final last = thread.lastResultDate;
    if (last == null) return false;
    return clock.difference(last).inDays >= 14;
  }

  String _clip(String raw, int max) {
    if (raw.length <= max) return raw;
    return '${raw.substring(0, max - 1)}…';
  }
}
