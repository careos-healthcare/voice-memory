import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:meta/meta.dart';

/// Manages active persona ([AppMode]), permissions, and session validation.
class CaregiverModeController {
  CaregiverModeController({
    required this._modeStore,
    required this._auditStore,
    required this._verificationService,
  });

  static CaregiverModeController? _instance;

  static CaregiverModeController get instance {
    final existing = _instance;
    if (existing == null) {
      throw StateError(
        'CaregiverModeController not configured — call configure() during bootstrap',
      );
    }
    return existing;
  }

  static bool get isConfigured => _instance != null;

  static Future<String?> tryRedirectFor(String path) async {
    if (_instance == null) return null;
    return _instance!.redirectFor(path);
  }

  static void configure(
    MobilePrefsStore prefs, {
    ConsentVerificationService? verification,
  }) {
    _instance = CaregiverModeController(
      modeStore: CaregiverModeStore(prefs),
      auditStore: CaregiverAuditStore(prefs),
      verificationService: verification ?? ConsentVerificationService(),
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  final CaregiverModeStore _modeStore;
  final CaregiverAuditStore _auditStore;
  final ConsentVerificationService _verificationService;

  CaregiverAccessService get accessService => CaregiverAccessService(
        auditStore: _auditStore,
        modeStore: _modeStore,
      );

  CaregiverAuditStore get auditStore => _auditStore;

  AppModeState _cachedMode = AppModeState.initial();
  CaregiverSession? _cachedSession;

  AppModeState get modeState => _cachedMode;
  AppMode get activeMode => _cachedMode.mode;
  CaregiverSession? get activeSession => _cachedSession;

  bool get isCaregiverMonitoring =>
      CaregiverFeatureFlags.isCaregiverModeEnabled &&
      _cachedMode.mode == AppMode.caregiverMonitoring;

  bool get hasValidSession =>
      CaregiverFeatureFlags.isCaregiverModeEnabled &&
      _cachedSession != null &&
      !_cachedSession!.isExpired;

  Future<void> initialize() async {
    _cachedMode = await _modeStore.readMode();
    _cachedSession = await _modeStore.readSession();

    if (!CaregiverFeatureFlags.isCaregiverModeEnabled) {
      if (_cachedMode.mode == AppMode.caregiverMonitoring ||
          _cachedSession != null) {
        await _modeStore.clearMonitoringState();
        _cachedMode = await _modeStore.readMode();
        _cachedSession = null;
      }
      return;
    }

    if (_cachedSession != null && _cachedSession!.isExpired) {
      await _expireSession();
    } else if (_cachedSession != null) {
      await _revalidateStoredToken();
    }
  }

  /// The only paths an active caregiver session may reach.
  ///
  /// Deliberately a whitelist. The previous denylist named the shell routes and
  /// so let every export, capture, and settings path through, and would have
  /// let each new route through as it was added.
  static const Set<String> _caregiverPaths = {
    RouteCatalog.caregiverHome,
    RouteCatalog.caregiverConsent,
  };

  /// Router guard — returns redirect path when caregiver mode requires it.
  Future<String?> redirectFor(String path) async {
    // Checked before touching storage: with the capability compiled out this
    // runs on every navigation and must stay free.
    if (!CaregiverFeatureFlags.isCaregiverModeEnabled) {
      return _caregiverPaths.contains(path) ? RouteCatalog.recordHome : null;
    }

    await initialize();

    if (_cachedMode.mode != AppMode.caregiverMonitoring) {
      return _caregiverPaths.contains(path) ? RouteCatalog.recordHome : null;
    }

    if (!hasValidSession) {
      if (path != RouteCatalog.caregiverConsent) {
        return RouteCatalog.caregiverConsent;
      }
      return null;
    }

    if (path == RouteCatalog.caregiverConsent) {
      return RouteCatalog.caregiverHome;
    }
    if (_caregiverPaths.contains(path)) return null;

    // Everything else — export, capture, settings, the shell — belongs to the
    // owner.
    return RouteCatalog.caregiverHome;
  }

  Future<void> switchToSelfReflection() async {
    final priorSession = _cachedSession?.sessionId;
    await _modeStore.clearMonitoringState();
    _cachedMode = await _modeStore.readMode();
    _cachedSession = null;
    if (priorSession != null) {
      await _auditStore.append(
        sessionId: priorSession,
        action: CaregiverAuditAction.modeSwitched,
        resourceType: 'app_mode',
        metadata: {'mode': AppMode.selfReflection.wireValue},
      );
    }
  }

  Future<void> switchToCaregiverMonitoring({
    required CaregiverPermissions permissions,
  }) async {
    if (!CaregiverFeatureFlags.isCaregiverModeEnabled) {
      await _auditStore.append(
        sessionId: 'none',
        action: CaregiverAuditAction.accessDenied,
        resourceType: 'app_mode',
        metadata: {'reason': 'caregiver_mode_disabled'},
      );
      return;
    }

    const subjectAccountId = 'local_archive_owner';
    const caregiverId = 'local_caregiver_invite';
    final token = await _verificationService.issueToken(
      subjectAccountId: subjectAccountId,
      caregiverId: caregiverId,
      permissions: permissions,
    );
    await activateWithToken(token);
  }

  Future<CaregiverTokenVerificationResult> activateWithToken(
    MonitoringConsentToken token,
  ) async {
    if (!CaregiverFeatureFlags.isCaregiverModeEnabled) {
      await _auditStore.append(
        sessionId: token.tokenId,
        action: CaregiverAuditAction.accessDenied,
        resourceType: 'consent_token',
        resourceId: token.tokenId,
        metadata: {'reason': 'caregiver_mode_disabled'},
      );
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Caregiver monitoring mode is disabled',
      );
    }

    final result = await _verificationService.verify(token);
    if (!result.valid || result.session == null) {
      await _auditStore.append(
        sessionId: token.tokenId,
        action: CaregiverAuditAction.accessDenied,
        resourceType: 'consent_token',
        resourceId: token.tokenId,
        metadata: {'reason': result.reason ?? 'unknown'},
      );
      return result;
    }

    final session = result.session!;
    await _modeStore.writeStoredToken(token);
    await _modeStore.writeSession(session);
    _cachedSession = session;
    _cachedMode = await _modeStore.writeMode(
      AppModeState(
        mode: AppMode.caregiverMonitoring,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
        activeSessionId: session.sessionId,
      ),
    );

    await _auditStore.append(
      sessionId: session.sessionId,
      action: CaregiverAuditAction.consentGranted,
      resourceType: 'consent_token',
      resourceId: token.tokenId,
      metadata: {
        'caregiverId': token.caregiverId,
        'subjectAccountId': token.subjectAccountId,
        'expiresAt': token.expiresAt.toUtc().toIso8601String(),
      },
    );
    await _auditStore.append(
      sessionId: session.sessionId,
      action: CaregiverAuditAction.sessionStarted,
      resourceType: 'caregiver_session',
      resourceId: session.sessionId,
    );

    return result;
  }

  Future<void> revokeConsent() async {
    final token = await _modeStore.readStoredToken();
    if (token != null) {
      await revokeGrant(token.tokenId);
      return;
    }
    final sessionId = _cachedSession?.sessionId ?? 'none';
    await _auditStore.append(
      sessionId: sessionId,
      action: CaregiverAuditAction.consentRevoked,
      resourceType: 'consent_token',
    );
    await switchToSelfReflection();
  }

  Future<void> revokeGrant(String tokenId) async {
    final sessionId = _cachedSession?.sessionId ?? 'none';
    // Read before the local clear below — the server accepts the signed token
    // as an ownership-proof fallback for grants issued before it kept a
    // registry, and `clearMonitoringState` is about to drop it.
    final stored = await _modeStore.readStoredToken();
    await _verificationService.revokeToken(tokenId);
    await _auditStore.append(
      sessionId: sessionId,
      action: CaregiverAuditAction.consentRevoked,
      resourceType: 'consent_token',
      resourceId: tokenId,
    );

    if (stored?.tokenId == tokenId) {
      await _modeStore.clearMonitoringState();
      _cachedSession = null;
      _cachedMode = await _modeStore.readMode();
      if (sessionId != 'none') {
        await _auditStore.append(
          sessionId: sessionId,
          action: CaregiverAuditAction.modeSwitched,
          resourceType: 'app_mode',
          metadata: {'mode': AppMode.selfReflection.wireValue},
        );
      }
    }

    // Local revocation above is complete and unconditional; this only adds the
    // server side, and queues itself for retry when it cannot land.
    await ServerConsentRevocationCoordinator.instance.revokeOnServer(
      tokenId: tokenId,
      domain: ConsentRevocationDomain.caregiverMonitoring,
      token: stored?.tokenId == tokenId ? stored?.toJson() : null,
    );
  }

  Future<bool> ensureReadAllowed({
    required String streamId,
    required CaregiverAuditAction auditAction,
    String? resourceId,
  }) async {
    await initialize();
    final session = _cachedSession;
    if (!hasValidSession || session == null) {
      await _auditStore.append(
        sessionId: session?.sessionId ?? 'none',
        action: CaregiverAuditAction.accessDenied,
        resourceType: streamId,
        resourceId: resourceId,
        metadata: {'reason': 'no_valid_session'},
      );
      return false;
    }

    if (!session.permissions.allowsStream(streamId)) {
      await _auditStore.append(
        sessionId: session.sessionId,
        action: CaregiverAuditAction.accessDenied,
        resourceType: streamId,
        resourceId: resourceId,
        metadata: {'reason': 'stream_not_permitted'},
      );
      return false;
    }

    await _auditStore.append(
      sessionId: session.sessionId,
      action: auditAction,
      resourceType: streamId,
      resourceId: resourceId,
    );
    return true;
  }

  Future<void> _revalidateStoredToken() async {
    final token = await _modeStore.readStoredToken();
    if (token == null) {
      await _expireSession();
      return;
    }
    final result = await _verificationService.verify(token);
    if (!result.valid || result.session == null) {
      await _expireSession();
      return;
    }
    _cachedSession = result.session;
    await _modeStore.writeSession(_cachedSession);
    await _auditStore.append(
      sessionId: _cachedSession!.sessionId,
      action: CaregiverAuditAction.sessionValidated,
      resourceType: 'caregiver_session',
      resourceId: _cachedSession!.sessionId,
    );
  }

  Future<void> _expireSession() async {
    final sessionId = _cachedSession?.sessionId ?? 'none';
    await _auditStore.append(
      sessionId: sessionId,
      action: CaregiverAuditAction.sessionExpired,
      resourceType: 'caregiver_session',
    );
    _cachedSession = null;
    await _modeStore.clearMonitoringState();
    _cachedMode = await _modeStore.readMode();
  }
}