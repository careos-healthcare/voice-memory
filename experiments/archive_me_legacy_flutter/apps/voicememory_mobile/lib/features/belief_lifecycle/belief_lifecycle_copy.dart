import 'belief_lifecycle_models.dart';

/// User-facing belief lifecycle strings.
abstract class BeliefLifecycleCopy {
  BeliefLifecycleCopy._();

  static const String sectionTitle = 'Belief lifecycle';

  static const String firstSeenLabel = 'First Seen';
  static const String lastSeenLabel = 'Last Seen';
  static const String statusLabel = 'Status';
  static const String lastDetectedLabel = 'Last detected';

  static const String noLongerDetectedTitle = 'Belief No Longer Detected';

  static String statusLabelFor(BeliefLifecycleStatus status) =>
      switch (status) {
        BeliefLifecycleStatus.emerging => 'Emerging',
        BeliefLifecycleStatus.stable => 'Stable',
        BeliefLifecycleStatus.weakening => 'Weakening',
        BeliefLifecycleStatus.dormant => 'Dormant',
        BeliefLifecycleStatus.noLongerDetected => 'No Longer Detected',
      };

  static const String eventFirstAppearance = 'First appearance in the archive';
  static const String eventStrengthening = 'Evidence trend strengthened';
  static const String eventWeakening = 'Evidence trend weakened';
  static const String eventDeath = 'No longer detected in recent saved moments';
}
