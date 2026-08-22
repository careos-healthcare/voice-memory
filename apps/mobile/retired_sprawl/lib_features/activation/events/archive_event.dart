/// Local analytics event for v1 activation tracking.
class ArchiveEvent {
  const ArchiveEvent(this.name, {this.payload = const {}});

  final String name;
  final Map<String, String> payload;

  ArchiveEvent withPayload(Map<String, String> extra) => ArchiveEvent(
        name,
        payload: {...payload, ...extra},
      );
}