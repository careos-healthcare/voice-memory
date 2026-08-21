import 'package:device_calendar/device_calendar.dart';

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
  DeviceCalendarGateway({DeviceCalendarPlugin? plugin})
    : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  @override
  Future<List<McpCalendarEvent>> fetchEvents(McpCalendarQuery query) async {
    final permissionsResult = await _plugin.hasPermissions();
    if (permissionsResult.isSuccess != true ||
        permissionsResult.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.isSuccess != true || requested.data != true) {
        return const [];
      }
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    if (calendarsResult.isSuccess != true || calendarsResult.data == null) {
      return const [];
    }

    final calendars = calendarsResult.data!;
    final selectedCalendars = query.calendarIds == null
        ? calendars
        : calendars
              .where((calendar) => query.calendarIds!.contains(calendar.id))
              .toList();

    final events = <McpCalendarEvent>[];
    for (final calendar in selectedCalendars) {
      final calendarId = calendar.id;
      if (calendarId == null) continue;

      final eventsResult = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: query.start.toLocal(),
          endDate: query.end.toLocal(),
        ),
      );

      if (eventsResult.isSuccess != true || eventsResult.data == null) {
        continue;
      }

      for (final event in eventsResult.data!) {
        final start = event.start;
        final end = event.end;
        if (start == null || end == null) continue;

        events.add(
          McpCalendarEvent(
            id: event.eventId ?? '${calendarId}_${start.toIso8601String()}',
            title: event.title ?? '(untitled)',
            start: start.toUtc(),
            end: end.toUtc(),
            isAllDay: event.allDay ?? false,
            location: event.location,
            calendarName: calendar.name,
          ),
        );
      }
    }

    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
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
