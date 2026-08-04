/// One optional structured marker attached to a thread.
///
/// A marker is a short factual label — never an inferred trait — supplied by a
/// separate marker store. Changes treats markers as decoration on top of the
/// evidence, never as a reason a thread exists.
class ChangeStructuredMarker {
  const ChangeStructuredMarker({required this.label, required this.detail})
    : assert(label != '');

  final String label;
  final String detail;
}

/// Reads the markers a thread carries, if a marker store is installed.
typedef ChangeStructuredMarkerLookup =
    List<ChangeStructuredMarker> Function(String threadId);

/// The seam between Changes and an optional marker store.
///
/// The marker store lives outside this feature and may not exist at all. Every
/// read goes through here and yields an empty list when no store is installed,
/// so Changes renders identically with or without one.
abstract final class ChangeStructuredMarkers {
  ChangeStructuredMarkers._();

  static ChangeStructuredMarkerLookup? _lookup;

  static bool get isAvailable => _lookup != null;

  /// Installs a marker store. Passing null removes it again.
  static void install(ChangeStructuredMarkerLookup? lookup) => _lookup = lookup;

  static List<ChangeStructuredMarker> forThread(String threadId) {
    final lookup = _lookup;
    if (lookup == null) return const [];
    try {
      return List.unmodifiable(lookup(threadId));
    } on Object {
      // A missing or half-built marker store must never take Changes down.
      return const [];
    }
  }
}
