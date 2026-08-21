/// Product persona — clean mode switching without separate app binaries.
enum AppMode {
  selfReflection,
  caregiverMonitoring,
  professionalCoach,
}

extension AppModeJson on AppMode {
  String get wireValue => switch (this) {
        AppMode.selfReflection => 'selfReflection',
        AppMode.caregiverMonitoring => 'caregiverMonitoring',
        AppMode.professionalCoach => 'professionalCoach',
      };

  static AppMode? fromWire(String? raw) => switch (raw) {
        'selfReflection' => AppMode.selfReflection,
        'caregiverMonitoring' => AppMode.caregiverMonitoring,
        'professionalCoach' => AppMode.professionalCoach,
        _ => null,
      };
}

/// Defaults and policy version for persisted [AppMode] config.
abstract final class AppModeConfigPolicy {
  AppModeConfigPolicy._();

  static const int currentPolicyVersion = 1;
  static const AppMode defaultMode = AppMode.selfReflection;
}