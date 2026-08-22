import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart' show CaregiverModeController;
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/coach/client_consent_verification_service.dart';
import 'package:archiveme_mobile/features/coach/coach_client_relationship_store.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_store.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/relationships/coach_relationship_sync_service.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:meta/meta.dart';

/// Manages [AppMode.professionalCoach] — isolated from [CaregiverModeController].
class CoachModeController {
  CoachModeController({
    required this._modeStore,
    required this._relationshipStore,
    required this._verificationService,
    this._relationshipSync,
  });

  static CoachModeController? _instance;

  static CoachModeController get instance {
    final existing = _instance;
    if (existing == null) {
      throw StateError(
        'CoachModeController not configured — call configure() during bootstrap',
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
    ClientConsentVerificationService? verification,
    UserRelationshipRepository? relationshipRepository,
    CoachRelationshipSyncService? relationshipSync,
  }) {
    final relationshipStore = CoachClientRelationshipStore(prefs);
    final sync = relationshipSync ??
        (relationshipRepository == null
            ? null
            : CoachRelationshipSyncService(
                repository: relationshipRepository,
                relationshipStore: relationshipStore,
              ));

    _instance = CoachModeController(
      modeStore: CoachModeStore(prefs),
      relationshipStore: relationshipStore,
      verificationService: verification ?? ClientConsentVerificationService(),
      relationshipSync: sync,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  final CoachModeStore _modeStore;
  final CoachClientRelationshipStore _relationshipStore;
  final ClientConsentVerificationService _verificationService;
  final CoachRelationshipSyncService? _relationshipSync;

  AppModeState _cachedMode = AppModeState.initial();
  CoachSession? _cachedSession;

  AppModeState get modeState => _cachedMode;
  AppMode get activeMode => _cachedMode.mode;
  CoachSession? get activeSession => _cachedSession;

  bool get isProfessionalCoach => _cachedMode.mode == AppMode.professionalCoach;

  bool get hasValidSession =>
      _cachedSession != null && !_cachedSession!.isExpired;

  Future<void> initialize() async {
    _cachedMode = await _modeStore.readMode();
    _cachedSession = await _modeStore.readSession();
    if (_cachedSession != null && _cachedSession!.isExpired) {
      await _expireSession();
    } else if (_cachedSession != null) {
      await _revalidateStoredToken();
    }
    await _relationshipSync?.reconcileOnStartup();
  }

  Future<String?> redirectFor(String path) async {
    const coachPaths = {
      RouteCatalog.coachHome,
      RouteCatalog.coachClientConsent,
    };

    if (!BetaSurfacesFeatureFlags.professionalCoach) {
      if (coachPaths.contains(path) || path.startsWith('/coach')) {
        return RouteCatalog.accountHome;
      }
      return null;
    }

    await initialize();

    if (_cachedMode.mode != AppMode.professionalCoach) {
      if (path == RouteCatalog.coachClientConsent) return null;
      if (path == RouteCatalog.coachHome) {
        final activated = await activateFromStoredClientToken();
        if (activated.valid) return null;
        return RouteCatalog.recordHome;
      }
      return null;
    }

    if (coachPaths.contains(path)) return null;

    if (!hasValidSession) {
      final activated = await activateFromStoredClientToken();
      if (!activated.valid) {
        if (path != RouteCatalog.coachClientConsent) {
          return RouteCatalog.coachClientConsent;
        }
        return null;
      }
    }

    if (path == RouteCatalog.coachClientConsent) {
      return RouteCatalog.coachHome;
    }

    const shellPaths = {...RouteCatalog.primaryRoutes, '/'};
    if (shellPaths.contains(path)) {
      return RouteCatalog.coachHome;
    }

    return null;
  }

  Future<void> switchToSelfReflection() async {
    await _modeStore.clearCoachState();
    _cachedMode = await _modeStore.readMode();
    _cachedSession = null;
  }

  Future<CoachTokenVerificationResult> activateFromStoredClientToken() async {
    final token = await _modeStore.readStoredToken();
    if (token == null) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'No stored client consent token',
      );
    }
    return activateWithToken(token);
  }

  Future<CoachTokenVerificationResult> activateWithToken(
    CoachConsentToken token,
  ) async {
    final source = await _modeStore.readTokenSource();
    final result = await _verificationService.verify(token, source: source);
    if (!result.valid || result.session == null) {
      return result;
    }

    final session = result.session!;
    await _modeStore.writeStoredToken(token);
    await _modeStore.writeSession(session);
    _cachedSession = session;
    _cachedMode = await _modeStore.writeMode(
      AppModeState(
        mode: AppMode.professionalCoach,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
        activeSessionId: session.sessionId,
      ),
    );

    await _relationshipSync?.syncFromToken(token);

    return result;
  }

  Future<CoachClientRelationship> saveClientConsent({
    required CoachConsentToken token,
    String? clientDisplayName,
  }) async {
    final now = DateTime.now().toUtc();
    final relationship = CoachClientRelationship(
      relationshipId: token.relationshipId,
      coachId: token.coachId,
      clientAccountId: token.clientAccountId,
      clientDisplayName: clientDisplayName,
      status: CoachClientRelationshipStatus.active,
      permissions: token.permissions,
      createdAt: now,
      updatedAt: now,
      activeConsentTokenId: token.tokenId,
    );
    await _relationshipStore.save(relationship);
    await _modeStore.writeStoredToken(
      token,
      source: _verificationService.lastIssuanceSource,
    );
    await _relationshipSync?.syncFromCoachRelationship(relationship);
    return relationship;
  }

  Future<bool> ensureCoachReadAllowed({
    required String resourceType,
    String? resourceId,
  }) async {
    await initialize();
    if (!hasValidSession) return false;
    return true;
  }

  Future<void> _revalidateStoredToken() async {
    final token = await _modeStore.readStoredToken();
    if (token == null) {
      await _expireSession();
      return;
    }
    final source = await _modeStore.readTokenSource();
    final result = await _verificationService.verify(token, source: source);
    if (!result.valid || result.session == null) {
      await _expireSession();
      return;
    }
    _cachedSession = result.session;
    await _modeStore.writeSession(_cachedSession);
  }

  Future<void> _expireSession() async {
    _cachedSession = null;
    _cachedMode = await _modeStore.writeMode(
      AppModeState(
        mode: AppMode.professionalCoach,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}