import 'revenue_funnel_event.dart';

/// Developer/debug summary of captured revenue funnel events.
class RevenueFunnelSnapshot {
  const RevenueFunnelSnapshot({
    required this.totalValueEvents,
    required this.totalCtaEvents,
    required this.conversionSurfacesSeen,
    required this.noContentCaptured,
  });

  final int totalValueEvents;
  final int totalCtaEvents;
  final List<String> conversionSurfacesSeen;
  final bool noContentCaptured;

  static RevenueFunnelSnapshot fromEvents(
    Iterable<({RevenueFunnelEvent event, Map<String, Object> metadata})> events,
  ) {
    var valueEvents = 0;
    var ctaEvents = 0;
    final surfaces = <String>{};

    for (final record in events) {
      if (record.event.isValueEvent) {
        valueEvents++;
        final surface = record.metadata['surface'];
        if (surface is String && surface.isNotEmpty) {
          surfaces.add(surface);
        }
      }
      if (record.event.isCtaEvent) {
        ctaEvents++;
      }
    }

    return RevenueFunnelSnapshot(
      totalValueEvents: valueEvents,
      totalCtaEvents: ctaEvents,
      conversionSurfacesSeen: surfaces.toList()..sort(),
      noContentCaptured: _metadataHasNoContent(events),
    );
  }

  static bool _metadataHasNoContent(
    Iterable<({RevenueFunnelEvent event, Map<String, Object> metadata})> events,
  ) {
    const allowedKeys = {
      'entry_count',
      'source',
      'has_confirmed_repeat',
      'has_report_preview',
      'is_pro',
      'surface',
    };
    const forbiddenSubstrings = [
      'transcript',
      'body',
      'user_text',
      'content',
      'quote',
      'snippet',
      'belief',
      'medical',
      'therapy',
      'mood',
      'note',
    ];

    for (final record in events) {
      for (final entry in record.metadata.entries) {
        if (!allowedKeys.contains(entry.key)) return false;
        final value = entry.value.toString().toLowerCase();
        for (final forbidden in forbiddenSubstrings) {
          if (value.contains(forbidden)) return false;
        }
      }
    }
    return true;
  }
}
