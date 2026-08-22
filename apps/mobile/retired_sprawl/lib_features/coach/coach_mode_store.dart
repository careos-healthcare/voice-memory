import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/coach/client_consent_verification_service.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists coach sessions and consent tokens — separate keys from caregiver.
class CoachModeStore {
  CoachModeStore(this._prefs);

  static const sessionPrefsKey = 'coach_session_v1';
  static const tokenPrefsKey = 'coach_consent_token_v1';
  static const tokenSourcePrefsKey = 'coach_consent_token_source_v1';

  final MobilePrefsStore _prefs;

  Future<AppModeState> readMode() async {
    final raw = await _prefs.readJsonMap(CaregiverModeStore.modePrefsKey);
    if (raw == null) return AppModeState.initial();
    return AppModeState.fromJson(raw);
  }

  Future<AppModeState> writeMode(AppModeState state) async {
    await _prefs.writeJsonMap(CaregiverModeStore.modePrefsKey, state.toJson());
    return state;
  }

  Future<CoachSession?> readSession() async {
    final raw = await _prefs.readJsonMap(sessionPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return CoachSession.fromJson(raw);
  }

  Future<void> writeSession(CoachSession? session) async {
    if (session == null) {
      await _prefs.writeJsonMap(sessionPrefsKey, {});
      return;
    }
    await _prefs.writeJsonMap(sessionPrefsKey, session.toJson());
  }

  Future<CoachConsentToken?> readStoredToken() async {
    final raw = await _prefs.readJsonMap(tokenPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return CoachConsentToken.fromJson(raw);
  }

  Future<void> writeStoredToken(
    CoachConsentToken? token, {
    CoachConsentTokenSource? source,
  }) async {
    if (token == null) {
      await _prefs.writeJsonMap(tokenPrefsKey, {});
      return;
    }
    await _prefs.writeJsonMap(tokenPrefsKey, token.toJson());
    if (source != null) {
      await writeTokenSource(source);
    }
  }

  Future<CoachConsentTokenSource> readTokenSource() async {
    final raw = await _prefs.readString(tokenSourcePrefsKey);
    return switch (raw) {
      'server' => CoachConsentTokenSource.server,
      _ => CoachConsentTokenSource.local,
    };
  }

  Future<void> writeTokenSource(CoachConsentTokenSource source) async {
    final wire = switch (source) {
      CoachConsentTokenSource.server => 'server',
      CoachConsentTokenSource.local => 'local',
    };
    await _prefs.writeString(tokenSourcePrefsKey, wire);
  }

  Future<void> clearCoachState() async {
    await writeSession(null);
    await writeStoredToken(null);
    await writeTokenSource(CoachConsentTokenSource.local);
    await writeMode(
      AppModeState(
        mode: AppMode.selfReflection,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}