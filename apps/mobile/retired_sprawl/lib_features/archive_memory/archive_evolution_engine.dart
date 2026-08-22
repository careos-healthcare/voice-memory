import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/result_next_check_model.dart';

const _displayLimit = 20;

/// Builds a conservative evolution timeline from saved key moments and pattern
/// memory. Events are grounded in moment summaries — nothing is invented.
/// Returns null when there is not yet enough to show a useful timeline.
ArchiveEvolutionTimeline? buildArchiveEvolutionTimeline({
  PatternMemory? memory,
  List<KeyMoment> keyMoments = const [],
  PatternProgressMoment? progress,
  WeeklyPatternRecap? weeklyRecap,
  ResultNextCheck? nextCheck,
}) {
  final patternTitle =
      _firstNonEmpty([
        memory?.patternTitle,
        weeklyRecap?.patternTitle,
        _firstMomentTitle(keyMoments),
      ]) ??
      'This pattern';

  final related = _relatedMoments(keyMoments, patternTitle);
  if (related.isEmpty) return null;

  final sorted = List<KeyMoment>.from(related)
    ..sort((a, b) => a.date.compareTo(b.date));

  if (sorted.length < 2) return null;

  final allEvents = <ArchiveEvolutionEvent>[];
  for (var i = 0; i < sorted.length; i++) {
    final moment = sorted[i];
    final type = i == 0
        ? ArchiveEvolutionEventType.firstSeen
        : _typeForMoment(moment);
    allEvents.add(_eventFromMoment(moment, type));
  }

  if (allEvents.length < 2) return null;

  allEvents.sort((a, b) => a.date.compareTo(b.date));

  final totalCount = allEvents.length;
  final displayed = totalCount <= _displayLimit
      ? allEvents
      : allEvents.sublist(totalCount - _displayLimit);

  final firstSeen = sorted.first.date;
  final lastSeen = sorted.last.date;

  final resolvedNextCheck = _firstNonEmpty([
    nextCheck?.nextQuestion,
    progress?.nextLine,
    weeklyRecap?.nextQuestion,
    memory?.nextBestQuestion,
    _latestNextCheck(sorted),
  ]);

  return ArchiveEvolutionTimeline(
    patternTitle: patternTitle,
    events: displayed,
    firstSeenDate: firstSeen,
    lastSeenDate: lastSeen,
    eventCount: totalCount,
    nextCheck: resolvedNextCheck,
  );
}

ArchiveEvolutionEventType _typeForMoment(KeyMoment moment) {
  final check = (moment.nextCheck ?? '').trim();
  final hint = (moment.resultHint ?? '').trim();
  if (check.isNotEmpty && hint.isEmpty) {
    return ArchiveEvolutionEventType.checkChosen;
  }
  switch (hint) {
    case 'same':
    case 'showed_up_again':
      return ArchiveEvolutionEventType.showedAgain;
    case 'lighter':
      return ArchiveEvolutionEventType.feltLighter;
    case 'heavier':
      return ArchiveEvolutionEventType.feltHeavier;
    case 'changed':
    case 'not_today':
    case 'none_fit':
      return ArchiveEvolutionEventType.changed;
    default:
      return ArchiveEvolutionEventType.keyMoment;
  }
}

ArchiveEvolutionEvent _eventFromMoment(
  KeyMoment moment,
  ArchiveEvolutionEventType type,
) {
  return ArchiveEvolutionEvent(
    id: moment.id,
    date: moment.date,
    type: type,
    title: _titleForType(type),
    body:
        type == ArchiveEvolutionEventType.checkChosen &&
            (moment.nextCheck ?? '').trim().isNotEmpty
        ? moment.nextCheck!.trim()
        : _bodyForMoment(moment),
    patternTitle: moment.patternTitle,
    nextCheck: moment.nextCheck,
    momentId: moment.id,
  );
}

String _titleForType(ArchiveEvolutionEventType type) {
  switch (type) {
    case ArchiveEvolutionEventType.firstSeen:
      return 'First seen';
    case ArchiveEvolutionEventType.showedAgain:
      return 'Showed up again';
    case ArchiveEvolutionEventType.feltLighter:
      return 'Felt lighter';
    case ArchiveEvolutionEventType.feltHeavier:
      return 'Felt heavier';
    case ArchiveEvolutionEventType.changed:
      return 'Changed';
    case ArchiveEvolutionEventType.checkChosen:
      return 'Check chosen';
    case ArchiveEvolutionEventType.keyMoment:
      return 'Moment saved';
  }
}

String _bodyForMoment(KeyMoment moment) {
  if (moment.shortSummary.trim().isNotEmpty) return moment.shortSummary.trim();
  if (moment.originalText.trim().isNotEmpty) {
    final text = moment.originalText.trim();
    return text.length > 120 ? '${text.substring(0, 117)}...' : text;
  }
  return moment.title;
}

List<KeyMoment> _relatedMoments(List<KeyMoment> moments, String patternTitle) {
  final target = patternTitle.trim().toLowerCase();
  final matched = moments
      .where((m) => (m.patternTitle ?? '').trim().toLowerCase() == target)
      .toList();
  return matched.isNotEmpty ? matched : moments;
}

String? _firstMomentTitle(List<KeyMoment> moments) {
  for (final m in moments) {
    final t = (m.patternTitle ?? '').trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String? _latestNextCheck(List<KeyMoment> moments) {
  for (final m in moments.reversed) {
    final check = (m.nextCheck ?? '').trim();
    if (check.isNotEmpty) return check;
  }
  return null;
}