import 'package:flutter/foundation.dart';

import '../../billing/archive_entitlement_reader.dart';
import '../../config/app_config.dart';
import '../../storage/mobile_prefs_store.dart';

enum ArchiveLoopEntitlementFeature { map, evidence, edit, returnCheck }

extension ArchiveLoopEntitlementFeatureIds on ArchiveLoopEntitlementFeature {
  String get id => name;
}

class ArchiveLoopEntitlementState {
  const ArchiveLoopEntitlementState({
    this.isPro = false,
    this.hasCompletedFirstLoop = false,
    this.freeLoopMapUsed = false,
    this.freeReturnCheckUsed = false,
    this.freeNodeEditUsed = false,
    this.mapCount = 0,
    this.evidenceCount = 0,
    this.editCount = 0,
    this.returnCheckCount = 0,
    this.postActivationPaywallDismissed = false,
  });

  final bool isPro;
  final bool hasCompletedFirstLoop;
  final bool freeLoopMapUsed;
  final bool freeReturnCheckUsed;
  final bool freeNodeEditUsed;
  final int mapCount;
  final int evidenceCount;
  final int editCount;
  final int returnCheckCount;
  final bool postActivationPaywallDismissed;

  static const empty = ArchiveLoopEntitlementState();

  ArchiveLoopEntitlementState copyWith({
    bool? isPro,
    bool? hasCompletedFirstLoop,
    bool? freeLoopMapUsed,
    bool? freeReturnCheckUsed,
    bool? freeNodeEditUsed,
    int? mapCount,
    int? evidenceCount,
    int? editCount,
    int? returnCheckCount,
    bool? postActivationPaywallDismissed,
  }) {
    return ArchiveLoopEntitlementState(
      isPro: isPro ?? this.isPro,
      hasCompletedFirstLoop:
          hasCompletedFirstLoop ?? this.hasCompletedFirstLoop,
      freeLoopMapUsed: freeLoopMapUsed ?? this.freeLoopMapUsed,
      freeReturnCheckUsed: freeReturnCheckUsed ?? this.freeReturnCheckUsed,
      freeNodeEditUsed: freeNodeEditUsed ?? this.freeNodeEditUsed,
      mapCount: mapCount ?? this.mapCount,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      editCount: editCount ?? this.editCount,
      returnCheckCount: returnCheckCount ?? this.returnCheckCount,
      postActivationPaywallDismissed:
          postActivationPaywallDismissed ?? this.postActivationPaywallDismissed,
    );
  }

  Map<String, dynamic> toJson() => {
    'isPro': isPro,
    'hasCompletedFirstLoop': hasCompletedFirstLoop,
    'freeLoopMapUsed': freeLoopMapUsed,
    'freeReturnCheckUsed': freeReturnCheckUsed,
    'freeNodeEditUsed': freeNodeEditUsed,
    'mapCount': mapCount,
    'evidenceCount': evidenceCount,
    'editCount': editCount,
    'returnCheckCount': returnCheckCount,
    'postActivationPaywallDismissed': postActivationPaywallDismissed,
  };

  static ArchiveLoopEntitlementState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return ArchiveLoopEntitlementState(
      isPro: json['isPro'] == true,
      hasCompletedFirstLoop: json['hasCompletedFirstLoop'] == true,
      freeLoopMapUsed: json['freeLoopMapUsed'] == true,
      freeReturnCheckUsed: json['freeReturnCheckUsed'] == true,
      freeNodeEditUsed: json['freeNodeEditUsed'] == true,
      mapCount: _readInt(json['mapCount']),
      evidenceCount: _readInt(json['evidenceCount']),
      editCount: _readInt(json['editCount']),
      returnCheckCount: _readInt(json['returnCheckCount']),
      postActivationPaywallDismissed:
          json['postActivationPaywallDismissed'] == true,
    );
  }
}

class ArchiveLoopEntitlementSnapshot {
  const ArchiveLoopEntitlementSnapshot({
    required this.state,
    required this.isPro,
  });

  final ArchiveLoopEntitlementState state;
  final bool isPro;

  bool get effectivePro => isPro || state.isPro;
}

class ArchiveLoopEntitlementStore {
  ArchiveLoopEntitlementStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'archiveLoopEntitlement';

  Future<ArchiveLoopEntitlementState> load() async {
    return ArchiveLoopEntitlementState.fromJson(await _prefs.readMap(_key));
  }

  Future<ArchiveLoopEntitlementState> save(
    ArchiveLoopEntitlementState state,
  ) async {
    await _prefs.writeMap(_key, state.toJson());
    return state;
  }

  Future<ArchiveLoopEntitlementState> _mutate(
    ArchiveLoopEntitlementState Function(ArchiveLoopEntitlementState current)
    change,
  ) async {
    final raw = await _prefs.updateMap(_key, (current) {
      final state = ArchiveLoopEntitlementState.fromJson(current);
      return change(state).toJson();
    });
    return ArchiveLoopEntitlementState.fromJson(raw);
  }

  Future<ArchiveLoopEntitlementState> markFirstLoopCompleted() {
    return _mutate(
      (s) => s.copyWith(hasCompletedFirstLoop: true, freeLoopMapUsed: true),
    );
  }

  Future<ArchiveLoopEntitlementState> markFreeReturnCheckUsed() {
    return _mutate((s) => s.copyWith(freeReturnCheckUsed: true));
  }

  Future<ArchiveLoopEntitlementState> markFreeNodeEditUsed() {
    return _mutate((s) => s.copyWith(freeNodeEditUsed: true));
  }

  Future<ArchiveLoopEntitlementState> incrementMapCount() {
    return _mutate((s) => s.copyWith(mapCount: s.mapCount + 1));
  }

  Future<ArchiveLoopEntitlementState> incrementEvidenceCount() {
    return _mutate((s) => s.copyWith(evidenceCount: s.evidenceCount + 1));
  }

  Future<ArchiveLoopEntitlementState> incrementEditCount() {
    return _mutate((s) => s.copyWith(editCount: s.editCount + 1));
  }

  Future<ArchiveLoopEntitlementState> incrementReturnCheckCount() {
    return _mutate((s) => s.copyWith(returnCheckCount: s.returnCheckCount + 1));
  }

  Future<ArchiveLoopEntitlementState> setPro(bool value) {
    if (value) {
      ArchiveLoopEntitlementLog.logProActive(source: 'store');
    }
    return _mutate((s) => s.copyWith(isPro: value));
  }

  /// Debug / integration-test hook — never call from production UI paths.
  Future<ArchiveLoopEntitlementState> setProDebug(bool value) {
    if (value) {
      ArchiveLoopEntitlementLog.logProActive(source: 'debug');
    }
    return _mutate((s) => s.copyWith(isPro: value));
  }

  Future<ArchiveLoopEntitlementState> markPaywallDismissed() {
    return _mutate((s) => s.copyWith(postActivationPaywallDismissed: true));
  }

  @visibleForTesting
  Future<void> clearAll() async {
    await _prefs.writeMap(_key, {});
  }
}

abstract class ArchiveLoopPaywallCopy {
  ArchiveLoopPaywallCopy._();

  static const headline = 'Keep testing your loop';
  static const subheadline =
      'You built a map from your own words. Pro keeps tracking what repeats, '
      'what changes, and what helps you stop the loop sooner.';
  static const priceFallback = 'Pro keeps tracking this loop over time.';
  static const priceUnavailable =
      'Purchases are not available right now. You can keep using your first map.';
  static const unavailableHint =
      'Purchases are not available right now. You can dismiss and keep your first map.';
  static const productUnavailableTitle =
      'Subscriptions are not available right now';
  static const productUnavailableBody =
      'ArchiveMe could not load subscription options. You can still use your free loop map and try again later.';
  static const tryAgainCta = 'Try again';
  static const purchaseFailedHint =
      'Purchase did not complete. You can try again or continue with your free map.';
  static const startProCta = 'Keep testing this loop';
  static const restoreCta = 'Restore purchases';
  static const notNowCta = 'Not now';

  static const subscriptionDetailsTitle = 'Subscription details';
  static const subscriptionAutoRenewingSummary =
      'Monthly or yearly auto-renewing subscription.';
  static const subscriptionMonthlyTitle = 'ArchiveMe Pro Monthly';
  static const subscriptionMonthlyDuration = 'Monthly plan renews every month.';
  static const subscriptionYearlyTitle = 'ArchiveMe Pro Yearly';
  static const subscriptionYearlyDuration = 'Yearly plan renews every year.';
  static const subscriptionPriceUnavailable =
      'Price shown by Apple at purchase.';
  static const subscriptionPlansUnavailable =
      'Monthly and yearly plans will appear when App Store products finish loading.';
  static const subscriptionAutoRenewal =
      'Subscription renews automatically unless cancelled at least 24 hours '
      'before the end of the current period.';
  static const subscriptionCancellation =
      'Manage or cancel your subscription in your Apple ID subscription settings.';
  static const privacyPolicyUrl = AppConfig.privacyUrl;
  static const privacyPolicyLabel = 'Privacy Policy';
  static const eulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const eulaLabel = 'Terms of Use';

  static const bullets = [
    'Save evidence to the exact part of the loop',
    'Track whether the same thought comes back tomorrow',
    'Edit the map in your own words',
    'See how the loop changes over time',
  ];

  static String featureHeadline(ArchiveLoopEntitlementFeature? feature) {
    return switch (feature) {
      ArchiveLoopEntitlementFeature.returnCheck => 'Keep testing what changed',
      ArchiveLoopEntitlementFeature.edit => 'Keep your loop map alive',
      ArchiveLoopEntitlementFeature.evidence => 'Keep your loop map alive',
      ArchiveLoopEntitlementFeature.map => 'Keep your loop map alive',
      null => headline,
    };
  }

  static String featureGateLine(ArchiveLoopEntitlementFeature? feature) {
    return switch (feature) {
      ArchiveLoopEntitlementFeature.returnCheck =>
        'Free shows the first loop. Pro tracks whether it comes back or '
            'changes over time.',
      ArchiveLoopEntitlementFeature.evidence =>
        'Pro saves the evidence trail so the map can change with you.',
      ArchiveLoopEntitlementFeature.edit || ArchiveLoopEntitlementFeature.map =>
        'Your first loop map is free. Pro keeps future tests, edits, and '
            'changes connected to the same map.',
      null => '',
    };
  }
}

abstract class ArchiveLoopEntitlementGate {
  ArchiveLoopEntitlementGate._();

  static Future<ArchiveLoopEntitlementSnapshot> load({
    ArchiveLoopEntitlementStore? store,
    ArchiveEntitlementReader? reader,
  }) async {
    final entitlementStore = store;
    final state = entitlementStore == null
        ? ArchiveLoopEntitlementState.empty
        : await entitlementStore.load();
    final entitlementReader =
        reader ?? ArchiveEntitlementReader.forAccessCheck();
    final billingPro = entitlementStore != null
        ? await entitlementReader.isPro
        : false;
    final isPro = billingPro || state.isPro;
    if (billingPro && store != null && !state.isPro) {
      await store.setPro(true);
      ArchiveLoopEntitlementLog.logProActive(source: 'billing');
    }
    return ArchiveLoopEntitlementSnapshot(
      state: isPro ? state.copyWith(isPro: true) : state,
      isPro: isPro,
    );
  }

  static bool canCreateNewMap(ArchiveLoopEntitlementSnapshot snap) {
    if (snap.effectivePro) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.map);
      return true;
    }
    if (!snap.state.hasCompletedFirstLoop) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.map);
      return true;
    }
    final allowed = snap.state.mapCount < 1;
    if (allowed) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.map);
    } else {
      ArchiveLoopEntitlementLog.logBlocked(ArchiveLoopEntitlementFeature.map);
    }
    return allowed;
  }

  static bool canSaveEvidence(ArchiveLoopEntitlementSnapshot snap) {
    if (snap.effectivePro) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.evidence,
      );
      return true;
    }
    if (!snap.state.hasCompletedFirstLoop) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.evidence,
      );
      return true;
    }
    final allowed = snap.state.evidenceCount < 3;
    if (allowed) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.evidence,
      );
    } else {
      ArchiveLoopEntitlementLog.logBlocked(
        ArchiveLoopEntitlementFeature.evidence,
      );
    }
    return allowed;
  }

  static bool canEditNode(ArchiveLoopEntitlementSnapshot snap) {
    if (snap.effectivePro) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.edit);
      return true;
    }
    if (!snap.state.hasCompletedFirstLoop) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.edit);
      return true;
    }
    final allowed = snap.state.editCount < 1;
    if (allowed) {
      ArchiveLoopEntitlementLog.logAllowed(ArchiveLoopEntitlementFeature.edit);
    } else {
      ArchiveLoopEntitlementLog.logBlocked(ArchiveLoopEntitlementFeature.edit);
    }
    return allowed;
  }

  static bool canCreateReturnCheck(ArchiveLoopEntitlementSnapshot snap) {
    if (snap.effectivePro) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.returnCheck,
      );
      return true;
    }
    if (!snap.state.hasCompletedFirstLoop) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.returnCheck,
      );
      return true;
    }
    final allowed = snap.state.returnCheckCount < 1;
    if (allowed) {
      ArchiveLoopEntitlementLog.logAllowed(
        ArchiveLoopEntitlementFeature.returnCheck,
      );
    } else {
      ArchiveLoopEntitlementLog.logBlocked(
        ArchiveLoopEntitlementFeature.returnCheck,
      );
    }
    return allowed;
  }

  static bool shouldShowPostActivationPaywall(
    ArchiveLoopEntitlementSnapshot snap,
  ) {
    return snap.state.hasCompletedFirstLoop &&
        !snap.effectivePro &&
        !snap.state.postActivationPaywallDismissed;
  }

  static bool shouldShowUpgradeForFeature({
    required ArchiveLoopEntitlementSnapshot snap,
    required ArchiveLoopEntitlementFeature feature,
  }) {
    if (snap.effectivePro) return false;
    return switch (feature) {
      ArchiveLoopEntitlementFeature.map => !canCreateNewMap(snap),
      ArchiveLoopEntitlementFeature.evidence => !canSaveEvidence(snap),
      ArchiveLoopEntitlementFeature.edit => !canEditNode(snap),
      ArchiveLoopEntitlementFeature.returnCheck => !canCreateReturnCheck(snap),
    };
  }

  static Future<bool> ensureAllowed({
    required ArchiveLoopEntitlementFeature feature,
    ArchiveLoopEntitlementStore? store,
    ArchiveEntitlementReader? reader,
  }) async {
    if (store == null) return true;
    final snap = await load(store: store, reader: reader);
    return switch (feature) {
      ArchiveLoopEntitlementFeature.map => canCreateNewMap(snap),
      ArchiveLoopEntitlementFeature.evidence => canSaveEvidence(snap),
      ArchiveLoopEntitlementFeature.edit => canEditNode(snap),
      ArchiveLoopEntitlementFeature.returnCheck => canCreateReturnCheck(snap),
    };
  }
}

abstract class ArchiveLoopEntitlementCoordinator {
  ArchiveLoopEntitlementCoordinator._();

  static ArchiveLoopEntitlementStore store(MobilePrefsStore prefs) =>
      ArchiveLoopEntitlementStore(prefs);

  static Future<void> onFirstLoopActivationCompleted(
    MobilePrefsStore prefs,
  ) async {
    final entitlementStore = store(prefs);
    await entitlementStore.markFirstLoopCompleted();
    await entitlementStore.incrementMapCount();
    await entitlementStore.markFreeReturnCheckUsed();
    await entitlementStore.incrementReturnCheckCount();
  }

  static Future<void> onMapGenerated(MobilePrefsStore prefs) async {
    final entitlementStore = store(prefs);
    final state = await entitlementStore.load();
    if (!state.hasCompletedFirstLoop) return;
    await entitlementStore.incrementMapCount();
  }

  static Future<void> onEvidenceSaved(MobilePrefsStore prefs) async {
    await store(prefs).incrementEvidenceCount();
  }

  static Future<void> onNodeEditSaved(MobilePrefsStore prefs) async {
    final entitlementStore = store(prefs);
    final state = await entitlementStore.load();
    if (!state.hasCompletedFirstLoop) {
      await entitlementStore.markFreeNodeEditUsed();
    }
    await entitlementStore.incrementEditCount();
  }

  static Future<void> onReturnCheckSaved(MobilePrefsStore prefs) async {
    final entitlementStore = store(prefs);
    final state = await entitlementStore.load();
    if (!state.hasCompletedFirstLoop) {
      await entitlementStore.markFreeReturnCheckUsed();
    }
    await entitlementStore.incrementReturnCheckCount();
  }

  static Future<void> enableDebugPro(MobilePrefsStore prefs) async {
    await store(prefs).setProDebug(true);
  }
}

abstract class ArchiveLoopEntitlementLog {
  ArchiveLoopEntitlementLog._();

  static void logAllowed(ArchiveLoopEntitlementFeature feature) {
    debugPrint('ARCHIVEME_ENTITLEMENT_GATE_ALLOWED feature=${feature.id}');
  }

  static void logBlocked(ArchiveLoopEntitlementFeature feature) {
    debugPrint('ARCHIVEME_ENTITLEMENT_GATE_BLOCKED feature=${feature.id}');
  }

  static void logProActive({required String source}) {
    debugPrint('ARCHIVEME_ENTITLEMENT_PRO_ACTIVE source=$source');
  }
}

abstract class ArchiveLoopPaywallLog {
  ArchiveLoopPaywallLog._();

  static void logShown({
    required String trigger,
    ArchiveLoopEntitlementFeature? feature,
  }) {
    final featurePart = feature == null ? '' : ' feature=${feature.id}';
    debugPrint('ARCHIVEME_PAYWALL_SHOWN trigger=$trigger$featurePart');
  }

  static void logCtaTapped() {
    debugPrint('ARCHIVEME_PAYWALL_CTA_TAPPED');
  }

  static void logDismissed() {
    debugPrint('ARCHIVEME_PAYWALL_DISMISSED');
  }
}

int _readInt(Object? raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

ArchiveLoopEntitlementFeature? archiveLoopEntitlementFeatureFromId(
  String? raw,
) {
  if (raw == null || raw.isEmpty) return null;
  for (final feature in ArchiveLoopEntitlementFeature.values) {
    if (feature.id == raw) return feature;
  }
  return null;
}
