import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists [AppModeState] and active [CaregiverSession] per account namespace.
class CaregiverModeStore {
  CaregiverModeStore(this._prefs);

  static const modePrefsKey = 'app_mode_config_v1';
  static const sessionPrefsKey = 'caregiver_session_v1';
  static const tokenPrefsKey = 'caregiver_consent_token_v1';

  final MobilePrefsStore _prefs;

  Future<AppModeState> readMode() async {
    final raw = await _prefs.readJsonMap(modePrefsKey);
    if (raw == null) return AppModeState.initial();
    return AppModeState.fromJson(raw);
  }

  Future<AppModeState> writeMode(AppModeState state) async {
    if (state.mode == AppMode.caregiverMonitoring &&
        !CaregiverFeatureFlags.isCaregiverModeEnabled) {
      return writeMode(
        AppModeState(
          mode: AppMode.selfReflection,
          policyVersion: state.policyVersion,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
    await _prefs.writeJsonMap(modePrefsKey, state.toJson());
    return state;
  }

  Future<CaregiverSession?> readSession() async {
    final raw = await _prefs.readJsonMap(sessionPrefsKey);
    if (raw == null) return null;
    return CaregiverSession.fromJson(raw);
  }

  Future<void> writeSession(CaregiverSession? session) async {
    if (session == null) {
      await _prefs.writeJsonMap(sessionPrefsKey, {});
      return;
    }
    await _prefs.writeJsonMap(sessionPrefsKey, session.toJson());
  }

  Future<MonitoringConsentToken?> readStoredToken() async {
    final raw = await _prefs.readJsonMap(tokenPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return MonitoringConsentToken.fromJson(raw);
  }

  Future<void> writeStoredToken(MonitoringConsentToken? token) async {
    if (token == null) {
      await _prefs.writeJsonMap(tokenPrefsKey, {});
      return;
    }
    await _prefs.writeJsonMap(tokenPrefsKey, token.toJson());
  }

  Future<void> clearMonitoringState() async {
    await writeSession(null);
    await writeStoredToken(null);
    await writeMode(
      AppModeState(
        mode: AppMode.selfReflection,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}