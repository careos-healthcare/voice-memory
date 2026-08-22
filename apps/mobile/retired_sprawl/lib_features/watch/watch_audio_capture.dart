/// Incoming watch-recorded audio forwarded from iOS WCSession.
class WatchAudioCapture {
  const WatchAudioCapture({
    required this.path,
    this.durationSeconds,
    this.capturedAt,
  });

  final String path;
  final int? durationSeconds;
  final DateTime? capturedAt;

  /// Stable dedupe key — filename + capture timestamp when available.
  String get ingestKey {
    final name = path.split('/').last;
    if (capturedAt != null) {
      return '$name@${capturedAt!.toUtc().toIso8601String()}';
    }
    return name;
  }

  static WatchAudioCapture? fromPlatform(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return WatchAudioCapture(path: raw.trim());
    }
    if (raw is Map) {
      final path = raw['path']?.toString().trim() ?? '';
      if (path.isEmpty) return null;
      final durationRaw = raw['durationSeconds'];
      final duration = switch (durationRaw) {
        final int value => value,
        final double value => value.round(),
        final String value => int.tryParse(value),
        _ => null,
      };
      final capturedRaw = raw['capturedAt']?.toString();
      DateTime? capturedAt;
      if (capturedRaw != null && capturedRaw.isNotEmpty) {
        capturedAt = DateTime.tryParse(capturedRaw);
      }
      return WatchAudioCapture(
        path: path,
        durationSeconds: duration,
        capturedAt: capturedAt,
      );
    }
    return null;
  }
}