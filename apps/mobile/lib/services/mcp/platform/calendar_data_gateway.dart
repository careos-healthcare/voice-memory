/// Normalized calendar event returned by [fetchCalendarEvents].
class McpCalendarEvent {
  const McpCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
    this.location,
    this.calendarName,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String? location;
  final String? calendarName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'isAllDay': isAllDay,
    if (location != null) 'location': location,
    if (calendarName != null) 'calendarName': calendarName,
  };
}

/// Query window for calendar reads.
class McpCalendarQuery {
  const McpCalendarQuery({
    required this.start,
    required this.end,
    this.calendarIds,
  });

  factory McpCalendarQuery.fromJson(Map<String, dynamic> json) {
    final startRaw = json['start'];
    final endRaw = json['end'];
    final calendarIdsRaw = json['calendarIds'];

    return McpCalendarQuery(
      start: startRaw is String
          ? DateTime.parse(startRaw).toUtc()
          : DateTime.now().toUtc().subtract(const Duration(days: 7)),
      end: endRaw is String
          ? DateTime.parse(endRaw).toUtc()
          : DateTime.now().toUtc().add(const Duration(days: 7)),
      calendarIds: calendarIdsRaw is List
          ? calendarIdsRaw.whereType<String>().toList()
          : null,
    );
  }

  final DateTime start;
  final DateTime end;
  final List<String>? calendarIds;
}

/// Platform calendar reads — injectable for tests.
abstract class CalendarDataGateway {
  Future<List<McpCalendarEvent>> fetchEvents(McpCalendarQuery query);
}

class DeviceCalendarGateway implements CalendarDataGateway {
  const DeviceCalendarGateway();

  @override
  Future<List<McpCalendarEvent>> fetchEvents(McpCalendarQuery query) async {
    return const [];
  }
}

class FakeCalendarDataGateway implements CalendarDataGateway {
  FakeCalendarDataGateway({this.events = const []});

  List<McpCalendarEvent> events;
  int fetchCallCount = 0;
  McpCalendarQuery? lastQuery;

  @override
  Future<List<McpCalendarEvent>> fetchEvents(McpCalendarQuery query) async {
    fetchCallCount++;
    lastQuery = query;
    return List<McpCalendarEvent>.of(events);
  }
}
