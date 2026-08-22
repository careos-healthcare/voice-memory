import 'dart:async';

import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Whether remote processing is permitted for specific purposes on the active
/// account or guest namespace, plus audit metadata for settings surfaces.
class RemoteProcessingConsentState {
  const RemoteProcessingConsentState({
    required this.consented,
    required this.grantedPurposes,
    required this.consentedAt,
    required this.revokedAt,
    required this.policyVersion,
    required this.permittedCategories,
  });

  factory RemoteProcessingConsentState.fromJson(Map<String, dynamic> json) {
    final rawPurposes = json['grantedPurposes'];
    final rawCategories = json['permittedCategories'];
    final consentedAtRaw = json['consentedAt'];
    final revokedAtRaw = json['revokedAt'];
    final policyVersion = json['policyVersion'] is int
        ? json['policyVersion'] as int
        : 1;
    final consented = json['consented'] == true;

    Set<RemoteProcessingPurpose> grantedPurposes = {};
    if (rawPurposes is List) {
      grantedPurposes = _purposesFromStorageList(rawPurposes);
    } else if (consented && rawCategories is List) {
      grantedPurposes = _purposesFromLegacyCategories(rawCategories);
    }

    if (!consented) {
      grantedPurposes = {};
    }

    return RemoteProcessingConsentState(
      consented: consented,
      grantedPurposes: grantedPurposes,
      consentedAt: consentedAtRaw is String
          ? DateTime.tryParse(consentedAtRaw)?.toUtc()
          : null,
      revokedAt: revokedAtRaw is String
          ? DateTime.tryParse(revokedAtRaw)?.toUtc()
          : null,
      policyVersion: policyVersion,
      permittedCategories: rawCategories is List
          ? List<String>.unmodifiable(rawCategories.whereType<String>())
          : const [],
    );
  }

  /// Opt-in default: nothing is sent remotely until the customer says yes.
  static const RemoteProcessingConsentState unset =
      RemoteProcessingConsentState(
        consented: false,
        grantedPurposes: {},
        consentedAt: null,
        revokedAt: null,
        policyVersion: RemoteProcessingConsentStore.currentPolicyVersion,
        permittedCategories: [],
      );

  final bool consented;
  final Set<RemoteProcessingPurpose> grantedPurposes;
  final DateTime? consentedAt;
  final DateTime? revokedAt;
  final int policyVersion;

  /// Legacy v1 category tokens retained for settings history display.
  final List<String> permittedCategories;

  bool isPurposeGranted(RemoteProcessingPurpose purpose) {
    if (!consented) return false;
    if (policyVersion < RemoteProcessingConsentStore.currentPolicyVersion) {
      return grantedPurposes.contains(purpose);
    }
    return grantedPurposes.contains(purpose);
  }

  Map<String, dynamic> toJson() => {
    'consented': consented,
    'grantedPurposes': grantedPurposes
        .map((purpose) => purpose.storageKey)
        .toList(),
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
    'policyVersion': policyVersion,
    'permittedCategories': List<String>.of(permittedCategories),
  };

  static Set<RemoteProcessingPurpose> _purposesFromStorageList(List<dynamic> raw) {
    final purposes = <RemoteProcessingPurpose>{};
    for (final item in raw) {
      if (item is! String) continue;
      final purpose = RemoteProcessingPurposeStorage.fromStorageKey(item);
      if (purpose != null) purposes.add(purpose);
    }
    return purposes;
  }

  static Set<RemoteProcessingPurpose> _purposesFromLegacyCategories(
    List<dynamic> rawCategories,
  ) {
    final purposes = <RemoteProcessingPurpose>{};
    for (final item in rawCategories) {
      if (item is! String) continue;
      final purpose = RemoteProcessingPurposeStorage.fromLegacyCategory(item);
      if (purpose != null) purposes.add(purpose);
    }
    return purposes;
  }
}

/// Per-account-namespaced store for [RemoteProcessingConsentState].
class RemoteProcessingConsentStore {
  RemoteProcessingConsentStore(this._prefs);

  static const String prefsKey = 'remote_processing_consent_v1';
  static const int currentPolicyVersion = 2;

  static const List<String> legacyDefaultCategories = [
    'transcription',
    'reflection_analysis',
  ];

  final MobilePrefsStore _prefs;

  final StreamController<RemoteProcessingConsentState> _changes =
      StreamController<RemoteProcessingConsentState>.broadcast();

  /// Emits after every grant or withdrawal, so listeners such as
  /// `BackgroundSyncQueueGateway` react to consent instead of polling for it.
  Stream<RemoteProcessingConsentState> get onChanged => _changes.stream;

  Future<RemoteProcessingConsentState> current() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null) return RemoteProcessingConsentState.unset;
    return RemoteProcessingConsentState.fromJson(raw);
  }

  Future<bool> isConsentedNow() async => (await current()).consented;

  Future<bool> isPurposeGrantedNow(RemoteProcessingPurpose purpose) async {
    try {
      return (await current()).isPurposeGranted(purpose);
    } catch (_) {
      return false;
    }
  }

  Future<RemoteProcessingConsentState> grant({
    Set<RemoteProcessingPurpose>? purposes,
    int policyVersion = currentPolicyVersion,
    DateTime? now,
  }) {
    final granted = purposes ?? RemoteProcessingPurposeStorage.onboardingGrant;
    return _write(
      RemoteProcessingConsentState(
        consented: true,
        grantedPurposes: Set<RemoteProcessingPurpose>.of(granted),
        consentedAt: (now ?? DateTime.now()).toUtc(),
        revokedAt: null,
        policyVersion: policyVersion,
        permittedCategories: _legacyCategoriesFor(granted),
      ),
    );
  }

  Future<RemoteProcessingConsentState> grantPurpose(
    RemoteProcessingPurpose purpose, {
    DateTime? now,
  }) async {
    final existing = await current();
    final merged = {...existing.grantedPurposes, purpose};
    return grant(
      purposes: merged,
      policyVersion: currentPolicyVersion,
      now: now,
    );
  }

  Future<RemoteProcessingConsentState> withdraw({DateTime? now}) async {
    final existing = await current();
    return _write(
      RemoteProcessingConsentState(
        consented: false,
        grantedPurposes: {},
        consentedAt: existing.consentedAt,
        revokedAt: (now ?? DateTime.now()).toUtc(),
        policyVersion: existing.policyVersion,
        permittedCategories: existing.permittedCategories,
      ),
    );
  }

  Future<RemoteProcessingConsentState> _write(
    RemoteProcessingConsentState state,
  ) async {
    await _prefs.writeJsonMap(prefsKey, state.toJson());
    if (_changes.hasListener) _changes.add(state);
    return state;
  }

  static List<String> _legacyCategoriesFor(
    Set<RemoteProcessingPurpose> purposes,
  ) {
    final categories = <String>[];
    if (purposes.contains(RemoteProcessingPurpose.remoteTranscription)) {
      categories.add('transcription');
    }
    if (purposes.contains(RemoteProcessingPurpose.remoteReflection)) {
      categories.add('reflection_analysis');
    }
    return categories;
  }
}
