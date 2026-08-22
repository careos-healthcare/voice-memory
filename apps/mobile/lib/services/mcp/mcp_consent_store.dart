import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// OS data domains that MCP tools may read after explicit user consent.
enum McpOsDataDomain {
  calendar,
  health,
}

extension McpOsDataDomainStorage on McpOsDataDomain {
  String get storageKey => switch (this) {
    McpOsDataDomain.calendar => 'calendar',
    McpOsDataDomain.health => 'health',
  };

  static McpOsDataDomain? fromStorageKey(String raw) => switch (raw) {
    'calendar' => McpOsDataDomain.calendar,
    'health' => McpOsDataDomain.health,
    _ => null,
  };
}

/// Account-scoped consent for local MCP reads of OS-level data stores.
class McpOsDataConsentState {
  const McpOsDataConsentState({
    required this.consented,
    required this.grantedDomains,
    required this.consentedAt,
    required this.revokedAt,
    required this.policyVersion,
  });

  factory McpOsDataConsentState.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['grantedDomains'];
    final grantedDomains = <McpOsDataDomain>{};
    if (rawDomains is List) {
      for (final item in rawDomains) {
        if (item is! String) continue;
        final domain = McpOsDataDomainStorage.fromStorageKey(item);
        if (domain != null) grantedDomains.add(domain);
      }
    }

    final consentedAtRaw = json['consentedAt'];
    final revokedAtRaw = json['revokedAt'];
    final consented = json['consented'] == true;

    return McpOsDataConsentState(
      consented: consented,
      grantedDomains: consented ? grantedDomains : const {},
      consentedAt: consentedAtRaw is String
          ? DateTime.tryParse(consentedAtRaw)?.toUtc()
          : null,
      revokedAt: revokedAtRaw is String
          ? DateTime.tryParse(revokedAtRaw)?.toUtc()
          : null,
      policyVersion: json['policyVersion'] is int
          ? json['policyVersion'] as int
          : 1,
    );
  }

  static const McpOsDataConsentState unset = McpOsDataConsentState(
    consented: false,
    grantedDomains: {},
    consentedAt: null,
    revokedAt: null,
    policyVersion: McpOsDataConsentStore.currentPolicyVersion,
  );

  final bool consented;
  final Set<McpOsDataDomain> grantedDomains;
  final DateTime? consentedAt;
  final DateTime? revokedAt;
  final int policyVersion;

  bool isDomainGranted(McpOsDataDomain domain) {
    if (!consented) return false;
    return grantedDomains.contains(domain);
  }

  Map<String, dynamic> toJson() => {
    'consented': consented,
    'grantedDomains': grantedDomains
        .map((domain) => domain.storageKey)
        .toList(),
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
    'policyVersion': policyVersion,
  };
}

/// Per-account-namespaced store for [McpOsDataConsentState].
class McpOsDataConsentStore {
  McpOsDataConsentStore(this._prefs);

  static const String prefsKey = 'mcp_os_data_consent_v1';
  static const int currentPolicyVersion = 1;

  final MobilePrefsStore _prefs;

  Future<McpOsDataConsentState> current() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null) return McpOsDataConsentState.unset;
    return McpOsDataConsentState.fromJson(raw);
  }

  Future<bool> isDomainGrantedNow(McpOsDataDomain domain) async {
    try {
      return (await current()).isDomainGranted(domain);
    } catch (_, stackTrace) {
      return false;
    }
  }

  Future<McpOsDataConsentState> grant({
    required Set<McpOsDataDomain> domains,
    DateTime? now,
  }) {
    return _write(
      McpOsDataConsentState(
        consented: true,
        grantedDomains: Set<McpOsDataDomain>.of(domains),
        consentedAt: (now ?? DateTime.now()).toUtc(),
        revokedAt: null,
        policyVersion: currentPolicyVersion,
      ),
    );
  }

  Future<McpOsDataConsentState> grantDomain(
    McpOsDataDomain domain, {
    DateTime? now,
  }) async {
    final existing = await current();
    final merged = {...existing.grantedDomains, domain};
    return grant(domains: merged, now: now);
  }

  Future<McpOsDataConsentState> withdraw({DateTime? now}) async {
    final existing = await current();
    return _write(
      McpOsDataConsentState(
        consented: false,
        grantedDomains: const {},
        consentedAt: existing.consentedAt,
        revokedAt: (now ?? DateTime.now()).toUtc(),
        policyVersion: existing.policyVersion,
      ),
    );
  }

  Future<McpOsDataConsentState> _write(McpOsDataConsentState state) async {
    await _prefs.writeJsonMap(prefsKey, state.toJson());
    return state;
  }
}