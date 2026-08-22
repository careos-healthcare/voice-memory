import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:permission_handler/permission_handler.dart';

/// Local-only microphone onboarding funnel. Values are intentionally persisted
/// as stable snake_case strings for forward-compatible secure storage.
enum OnboardingMicState {
  notPrompted('not_prompted'),
  softPromptAccepted('soft_prompt_accepted'),
  granted('granted'),
  denied('denied'),
  permanentlyDenied('permanently_denied');

  const OnboardingMicState(this.storageValue);

  final String storageValue;

  static OnboardingMicState fromStorage(String? value) {
    return values.firstWhere(
      (state) => state.storageValue == value,
      orElse: () => OnboardingMicState.notPrompted,
    );
  }
}

class OnboardingMicStateStore {
  const OnboardingMicStateStore(this.prefs);

  static const String prefsKey = 'onboarding_mic_state';

  final MobilePrefsStore prefs;

  Future<OnboardingMicState> read() async =>
      OnboardingMicState.fromStorage(await prefs.readString(prefsKey));

  Future<void> write(OnboardingMicState state) =>
      prefs.writeString(prefsKey, state.storageValue);

  Future<OnboardingMicState> recordPermissionStatus(
    PermissionStatus status,
  ) async {
    final state = switch (status) {
      PermissionStatus.granted => OnboardingMicState.granted,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted ||
      PermissionStatus.limited => OnboardingMicState.permanentlyDenied,
      PermissionStatus.denied ||
      PermissionStatus.provisional => OnboardingMicState.denied,
    };
    await write(state);
    return state;
  }
}