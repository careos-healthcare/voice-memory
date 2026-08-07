import '../../storage/mobile_prefs_store.dart';

/// Whether remote processing (sending a transcript to the backend for AI
/// reflection/analysis) is currently permitted for the active account or
/// guest namespace, and the record of when/how that was decided.
///
/// [consented] is the live answer a capture-time gate reads. The rest is
/// bookkeeping the settings surface can show back to the customer.
class RemoteProcessingConsentState {
  const RemoteProcessingConsentState({
    required this.consented,
    required this.consentedAt,
    required this.policyVersion,
    required this.permittedCategories,
  });

  /// The state a namespace that has never recorded a decision reads as.
  /// Consent is opt-in: nothing is sent remotely until the customer has
  /// explicitly said yes.
  static const RemoteProcessingConsentState unset =
      RemoteProcessingConsentState(
        consented: false,
        consentedAt: null,
        policyVersion: 1,
        permittedCategories: [],
      );

  final bool consented;
  final DateTime? consentedAt;
  final int policyVersion;
  final List<String> permittedCategories;

  Map<String, dynamic> toJson() => {
    'consented': consented,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'policyVersion': policyVersion,
    'permittedCategories': List<String>.of(permittedCategories),
  };

  factory RemoteProcessingConsentState.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['permittedCategories'];
    final consentedAtRaw = json['consentedAt'];
    return RemoteProcessingConsentState(
      consented: json['consented'] == true,
      consentedAt: consentedAtRaw is String
          ? DateTime.tryParse(consentedAtRaw)?.toUtc()
          : null,
      policyVersion: json['policyVersion'] is int
          ? json['policyVersion'] as int
          : 1,
      permittedCategories: rawCategories is List
          ? List<String>.unmodifiable(rawCategories.whereType<String>())
          : const [],
    );
  }
}

/// Per-account-namespaced store for [RemoteProcessingConsentState].
///
/// Backed by whichever `MobilePrefsStore` is handed in — production wires
/// this to `AppServices.instance.prefs`, which Part A already namespaces per
/// account/guest, so opting in as one account (or as a guest) never leaks
/// into a different account's or a different guest session's state: each
/// namespace has its own prefs file, and therefore its own consent record.
///
/// Deliberately takes the prefs store as a constructor argument (matching
/// `ArchiveAgreementService.fromPrefs`'s pattern) rather than reaching for
/// `AppServices.instance` itself, so this is fully unit-testable against a
/// bare `MobilePrefsStore` with no app bootstrap required.
class RemoteProcessingConsentStore {
  RemoteProcessingConsentStore(this._prefs);

  static const String prefsKey = 'remote_processing_consent_v1';
  static const int currentPolicyVersion = 1;

  final MobilePrefsStore _prefs;

  /// The current decision, or [RemoteProcessingConsentState.unset] when this
  /// namespace has never recorded one — which is also what a brand-new
  /// namespace reads before the customer has ever seen the consent prompt.
  Future<RemoteProcessingConsentState> current() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null) return RemoteProcessingConsentState.unset;
    return RemoteProcessingConsentState.fromJson(raw);
  }

  /// Whether a *new* remote-processing attempt may proceed right now. A thin,
  /// named wrapper over [current] so a capture-time gate reads as an intent
  /// check rather than a state dump.
  Future<bool> isConsentedNow() async => (await current()).consented;

  /// Records an explicit opt-in. [permittedCategories] is a closed set of
  /// product-defined tokens (e.g. `'transcription'`, `'reflection_analysis'`)
  /// describing what the customer agreed to; defaults to allowing everything
  /// this store currently gates.
  Future<RemoteProcessingConsentState> grant({
    int policyVersion = currentPolicyVersion,
    List<String> permittedCategories = const [
      'transcription',
      'reflection_analysis',
    ],
    DateTime? now,
  }) => _write(
    RemoteProcessingConsentState(
      consented: true,
      consentedAt: (now ?? DateTime.now()).toUtc(),
      policyVersion: policyVersion,
      permittedCategories: List<String>.of(permittedCategories),
    ),
  );

  /// Records an explicit opt-out. `consentedAt` and `permittedCategories` are
  /// kept rather than cleared: they describe the *last* time the customer
  /// said yes and to what, which is useful history for the settings surface
  /// and for a support conversation about when consent was given and then
  /// withdrawn — clearing them would make a withdrawal look identical to a
  /// namespace that never consented at all. The only thing withdrawal changes
  /// is [RemoteProcessingConsentState.consented] itself, which is the only
  /// field the capture-time gate reads.
  Future<RemoteProcessingConsentState> withdraw({DateTime? now}) async {
    final existing = await current();
    return _write(
      RemoteProcessingConsentState(
        consented: false,
        consentedAt: existing.consentedAt,
        policyVersion: existing.policyVersion,
        permittedCategories: existing.permittedCategories,
      ),
    );
  }

  Future<RemoteProcessingConsentState> _write(
    RemoteProcessingConsentState state,
  ) async {
    await _prefs.writeJsonMap(prefsKey, state.toJson());
    return state;
  }
}
