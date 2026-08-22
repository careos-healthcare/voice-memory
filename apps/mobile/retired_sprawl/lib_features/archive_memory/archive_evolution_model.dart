/// How one pattern entry appears on the evolution timeline.
enum ArchiveEvolutionEventType {
  firstSeen,
  showedAgain,
  feltLighter,
  feltHeavier,
  changed,
  checkChosen,
  keyMoment,
}

extension ArchiveEvolutionEventTypeIds on ArchiveEvolutionEventType {
  String get id => name;
}

ArchiveEvolutionEventType archiveEvolutionEventTypeFromId(String? raw) {
  for (final t in ArchiveEvolutionEventType.values) {
    if (t.id == raw) return t;
  }
  return ArchiveEvolutionEventType.keyMoment;
}

/// One grounded moment on the pattern evolution timeline.
class ArchiveEvolutionEvent {
  const ArchiveEvolutionEvent({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    required this.body,
    this.patternTitle,
    this.nextCheck,
    this.momentId,
  });

  final String id;
  final DateTime date;
  final ArchiveEvolutionEventType type;
  final String title;
  final String body;
  final String? patternTitle;
  final String? nextCheck;
  final String? momentId;

  ArchiveEvolutionEvent copyWith({
    String? id,
    DateTime? date,
    ArchiveEvolutionEventType? type,
    String? title,
    String? body,
    String? patternTitle,
    String? nextCheck,
    String? momentId,
  }) {
    return ArchiveEvolutionEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      patternTitle: patternTitle ?? this.patternTitle,
      nextCheck: nextCheck ?? this.nextCheck,
      momentId: momentId ?? this.momentId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'type': type.id,
    'title': title,
    'body': body,
    if (patternTitle != null) 'patternTitle': patternTitle,
    if (nextCheck != null) 'nextCheck': nextCheck,
    if (momentId != null) 'momentId': momentId,
  };

  static ArchiveEvolutionEvent? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final title = map['title'] as String?;
    final body = map['body'] as String?;
    if (id == null || title == null || body == null) return null;
    final date = DateTime.tryParse(map['date'] as String? ?? '');
    if (date == null) return null;
    return ArchiveEvolutionEvent(
      id: id,
      date: date,
      type: archiveEvolutionEventTypeFromId(map['type'] as String?),
      title: title,
      body: body,
      patternTitle: map['patternTitle'] as String?,
      nextCheck: map['nextCheck'] as String?,
      momentId: map['momentId'] as String?,
    );
  }
}

/// A chronological view of how one pattern has shown up over time.
class ArchiveEvolutionTimeline {
  const ArchiveEvolutionTimeline({
    required this.patternTitle,
    required this.events,
    required this.eventCount,
    this.firstSeenDate,
    this.lastSeenDate,
    this.nextCheck,
  });

  final String patternTitle;
  final List<ArchiveEvolutionEvent> events;
  final DateTime? firstSeenDate;
  final DateTime? lastSeenDate;
  final int eventCount;
  final String? nextCheck;

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  ArchiveEvolutionTimeline copyWith({
    String? patternTitle,
    List<ArchiveEvolutionEvent>? events,
    DateTime? firstSeenDate,
    DateTime? lastSeenDate,
    int? eventCount,
    String? nextCheck,
  }) {
    return ArchiveEvolutionTimeline(
      patternTitle: patternTitle ?? this.patternTitle,
      events: events ?? this.events,
      firstSeenDate: firstSeenDate ?? this.firstSeenDate,
      lastSeenDate: lastSeenDate ?? this.lastSeenDate,
      eventCount: eventCount ?? this.eventCount,
      nextCheck: nextCheck ?? this.nextCheck,
    );
  }

  Map<String, dynamic> toJson() => {
    'patternTitle': patternTitle,
    'events': events.map((e) => e.toJson()).toList(),
    'eventCount': eventCount,
    if (firstSeenDate != null)
      'firstSeenDate': firstSeenDate!.toUtc().toIso8601String(),
    if (lastSeenDate != null)
      'lastSeenDate': lastSeenDate!.toUtc().toIso8601String(),
    if (nextCheck != null) 'nextCheck': nextCheck,
  };

  static ArchiveEvolutionTimeline? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final patternTitle = map['patternTitle'] as String?;
    if (patternTitle == null) return null;
    final list = map['events'];
    final events = <ArchiveEvolutionEvent>[];
    if (list is List) {
      for (final e in list) {
        final item = e is Map<String, dynamic>
            ? e
            : (e is Map ? Map<String, dynamic>.from(e) : null);
        final event = ArchiveEvolutionEvent.fromJson(item);
        if (event != null) events.add(event);
      }
    }
    return ArchiveEvolutionTimeline(
      patternTitle: patternTitle,
      events: events,
      eventCount: map['eventCount'] is int
          ? map['eventCount'] as int
          : (map['eventCount'] as num?)?.toInt() ?? events.length,
      firstSeenDate: DateTime.tryParse(map['firstSeenDate'] as String? ?? ''),
      lastSeenDate: DateTime.tryParse(map['lastSeenDate'] as String? ?? ''),
      nextCheck: map['nextCheck'] as String?,
    );
  }
}