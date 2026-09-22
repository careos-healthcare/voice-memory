import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether activity metadata came from detection or an explicit pick.
enum ActivitySource { detected, picked }

/// A short label for what the person is doing right now.
class ActivityMetadata {
  const ActivityMetadata({required this.label, required this.source});

  final String label;
  final ActivitySource source;
}

/// On-device activities offered when detection has nothing to report.
abstract final class ActivityCatalog {
  static const labels = <String>[
    'Walking',
    'Working',
    'Commuting',
    'Resting',
  ];
}

/// Detects the current activity without leaving the device.
abstract class ActivityDetector {
  const ActivityDetector();

  Future<ActivityMetadata?> detect();
}

/// Maps the local hour to an activity when no motion sensor is available.
class TimeOfDayActivityDetector extends ActivityDetector {
  TimeOfDayActivityDetector({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<ActivityMetadata?> detect() async {
    final hour = _clock().toLocal().hour;
    final label = switch (hour) {
      >= 5 && < 12 => 'Morning routine',
      >= 12 && < 17 => 'Midday focus',
      _ => 'Evening wind-down',
    };
    return ActivityMetadata(label: label, source: ActivitySource.detected);
  }
}

/// Detects current activity metadata, leaving a pick as the fallback.
class ActivityMetadataService {
  ActivityMetadataService({ActivityDetector? detector})
    : _detector = detector ?? TimeOfDayActivityDetector();

  final ActivityDetector _detector;

  Future<ActivityMetadata?> detectCurrent() => _detector.detect();
}

final activityMetadataServiceProvider = Provider<ActivityMetadataService>(
  (ref) => ActivityMetadataService(),
);
