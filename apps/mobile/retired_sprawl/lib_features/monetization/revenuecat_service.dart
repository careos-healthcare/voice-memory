import 'dart:async';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_constants.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Active RevenueCat entitlement for advanced AI and cross-platform continuity.
class PremiumEntitlement {
  const PremiumEntitlement({required this.isActive, this.isTrial = false});

  final bool isActive;
  final bool isTrial;

  static const free = PremiumEntitlement(isActive: false);
  static const active = PremiumEntitlement(isActive: true);
  static const trial = PremiumEntitlement(isActive: true, isTrial: true);

  bool get hasPremiumAccess => isActive || isTrial;

  bool get canUseSmartSummary => isActive;
  bool get canUseActionItems => isActive;
  bool get canUseCustomFormatting => isActive;
  bool get canUseUnlimitedWatchSync => isActive;
  bool get canUseCloudRelay => isActive;
  bool get canHandoffToWeb => isActive;

  /// Encrypted notes stay on device for every account.
  bool get canStoreEncryptedLocally => true;

  /// Basic recording does not require a subscription.
  bool get canCaptureAudio => true;

  /// Typed capture stays on device for every account.
  bool get canCaptureText => true;

  bool get canUseCloudBackup => hasPremiumAccess;
  bool get canUseObsidianSync => hasPremiumAccess;
  bool get canUsePatternSynthesis => hasPremiumAccess;

  bool get canUseMeshOffload => isActive;
  bool get canUseMultiDeviceSync => isActive;
  bool get canUseDeeperCoaching => isActive;
}

/// One free pattern synthesis, then the engine follows the receipt.
class PatternSynthesisTrial {
  static var previewsRemaining = 1;

  static bool allow(PremiumEntitlement entitlement) {
    if (FreeTierGate.allowsPatternSynthesis(entitlement, offline: false)) {
      return true;
    }
    if (previewsRemaining <= 0) return false;
    previewsRemaining -= 1;
    return true;
  }

  static void reset([int count = 1]) {
    previewsRemaining = count;
  }
}

/// Free capture and storage stay open. Premium features follow the receipt.
///
/// [offline] is accepted so callers can pass connectivity, and it is ignored.
/// A forced offline flag cannot grant mesh, sync, or deeper coaching.
abstract final class FreeTierGate {
  static bool allowsLocalArchive({required bool offline}) {
    final included = PremiumEntitlement.free.canStoreEncryptedLocally;
    if (offline) return included;
    return included;
  }

  static bool allowsAudioCapture({required bool offline}) {
    final included = PremiumEntitlement.free.canCaptureAudio;
    if (offline) return included;
    return included;
  }

  static bool allowsTextCapture({required bool offline}) {
    final included = PremiumEntitlement.free.canCaptureText;
    if (offline) return included;
    return included;
  }

  static bool allowsCloudBackup(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUseCloudBackup;
    return offline ? receipt : receipt;
  }

  static bool allowsObsidianSync(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUseObsidianSync;
    return offline ? receipt : receipt;
  }

  static bool allowsPatternSynthesis(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUsePatternSynthesis;
    return offline ? receipt : receipt;
  }

  static bool allowsMeshOffload(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUseMeshOffload;
    return offline ? receipt : receipt;
  }

  static bool allowsMultiDeviceSync(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUseMultiDeviceSync;
    return offline ? receipt : receipt;
  }

  static bool allowsDeeperCoaching(
    PremiumEntitlement entitlement, {
    required bool offline,
  }) {
    final receipt = entitlement.canUseDeeperCoaching;
    return offline ? receipt : receipt;
  }
}

/// Latest entitlement read by feature gates that are not widgets.
abstract final class PremiumAccess {
  static PremiumEntitlement current = PremiumEntitlement.free;

  static void apply(PremiumEntitlement entitlement) {
    current = entitlement;
  }
}

/// Free Watch sync is capped. Premium removes the cap.
abstract final class ContinuityGate {
  static var _freeWatchSyncsRemaining = 1;

  static bool allowWatchSync() {
    if (PremiumAccess.current.canUseUnlimitedWatchSync) return true;
    if (_freeWatchSyncsRemaining <= 0) return false;
    _freeWatchSyncsRemaining -= 1;
    return true;
  }

  static void resetFreeWatchQuota([int count = 1]) {
    _freeWatchSyncsRemaining = count;
  }
}

/// True when customer info includes an active `pro` or `archive_loop_pro`.
bool holdsContinuityEntitlement(PremiumEntitlements entitlements) {
  if (entitlements.isPro) return true;
  return RevenueCatConstants.entitlementIds.any(
    entitlements.entitlementIds.contains,
  );
}

/// Subscriptions through `purchases_flutter`, using the app's configured
/// RevenueCat client so [Purchases.configure] is not called a second time.
class MonetizationRevenueCatService {
  MonetizationRevenueCatService({
    RevenueCatService? sdk,
    PremiumEntitlement? seed,
    this.purchaseOverride,
    this.restoreOverride,
    Stream<PremiumEntitlement>? status,
  }) : _sdk = sdk,
       _seed = seed ?? PremiumEntitlement.free,
       _status = status;

  final RevenueCatService? _sdk;
  PremiumEntitlement _seed;
  final Stream<PremiumEntitlement>? _status;
  final Future<PremiumEntitlement> Function()? purchaseOverride;
  final Future<PremiumEntitlement> Function()? restoreOverride;

  PremiumEntitlement get current {
    final sdk = _sdk;
    if (sdk == null) return _seed;
    return _fromBilling(sdk.latestEntitlements);
  }

  Stream<PremiumEntitlement> get status {
    final override = _status;
    if (override != null) return override;
    final sdk = _sdk;
    if (sdk == null) return Stream.value(_seed);
    return sdk.entitlementStream.map(_fromBilling);
  }

  PremiumEntitlement _fromBilling(PremiumEntitlements entitlements) {
    return PremiumEntitlement(
      isActive: holdsContinuityEntitlement(entitlements),
    );
  }

  /// Configures RevenueCat once through [RevenueCatService.initialize], then
  /// reads [Purchases.getCustomerInfo] via that client.
  Future<PremiumEntitlement> refreshCustomerInfo() async {
    final sdk = _sdk;
    if (sdk == null) return current;
    await sdk.initialize();
    final entitlements = await sdk.refreshEntitlements();
    _seed = _fromBilling(entitlements);
    PremiumAccess.apply(_seed);
    return _seed;
  }

  Future<Offerings?> loadOfferings() {
    final sdk = _sdk;
    if (sdk == null) return Future.value();
    return sdk.fetchOfferings();
  }

  /// Purchases the current offering through [Purchases.purchasePackage].
  Future<PremiumEntitlement> purchaseCurrent() async {
    final override = purchaseOverride;
    if (override != null) {
      _seed = await override();
      PremiumAccess.apply(_seed);
      return _seed;
    }
    final sdk = _sdk;
    if (sdk == null) return current;
    await sdk.initialize();
    final offerings = await sdk.fetchOfferings();
    final packages = _packagesFor(offerings);
    if (packages.isEmpty) return current;
    return purchasePackage(packages.first);
  }

  /// Buys [package] with [Purchases.purchasePackage].
  Future<PremiumEntitlement> purchasePackage(Package package) async {
    final override = purchaseOverride;
    if (override != null) {
      _seed = await override();
      PremiumAccess.apply(_seed);
      return _seed;
    }
    final sdk = _sdk;
    if (sdk == null) return current;
    await sdk.initialize();
    final entitlements = await sdk.purchasePackage(package);
    _seed = _fromBilling(entitlements);
    PremiumAccess.apply(_seed);
    return _seed;
  }

  Future<PremiumEntitlement> restore() => restorePurchases();

  /// Restores the store receipt with [Purchases.restorePurchases].
  Future<PremiumEntitlement> restorePurchases() async {
    final override = restoreOverride;
    if (override != null) {
      _seed = await override();
      PremiumAccess.apply(_seed);
      return _seed;
    }
    final sdk = _sdk;
    if (sdk == null) return current;
    await sdk.initialize();
    final entitlements = await sdk.restorePurchases();
    _seed = _fromBilling(entitlements);
    PremiumAccess.apply(_seed);
    return _seed;
  }

  static List<Package> _packagesFor(Offerings? offerings) {
    final named = offerings?.all[RevenueCatConstants.currentOfferingId];
    final offering = named ?? offerings?.current;
    return offering?.availablePackages ?? const <Package>[];
  }
}

final monetizationRevenueCatServiceProvider =
    Provider<MonetizationRevenueCatService>(
      (ref) => MonetizationRevenueCatService(sdk: RevenueCatService.instance),
    );

/// Streams the active premium entitlement from RevenueCat.
class PremiumEntitlementProvider extends Notifier<PremiumEntitlement> {
  static const entitlementIds = RevenueCatConstants.entitlementIds;
  static const offeringId = RevenueCatConstants.currentOfferingId;

  @override
  PremiumEntitlement build() {
    final service = ref.watch(monetizationRevenueCatServiceProvider);
    final subscription = service.status.listen((entitlement) {
      PremiumAccess.apply(entitlement);
      state = entitlement;
    });
    ref.onDispose(subscription.cancel);
    final initial = service.current;
    PremiumAccess.apply(initial);
    unawaited(_refresh(service));
    return initial;
  }

  Future<void> _refresh(MonetizationRevenueCatService service) async {
    final next = await service.refreshCustomerInfo();
    if (!ref.mounted) return;
    PremiumAccess.apply(next);
    state = next;
  }

  Future<void> purchase() async {
    final next = await ref
        .read(monetizationRevenueCatServiceProvider)
        .purchaseCurrent();
    PremiumAccess.apply(next);
    state = next;
  }

  Future<void> restore() async {
    final next = await ref
        .read(monetizationRevenueCatServiceProvider)
        .restore();
    PremiumAccess.apply(next);
    state = next;
  }
}

final premiumEntitlementProvider =
    NotifierProvider<PremiumEntitlementProvider, PremiumEntitlement>(
      PremiumEntitlementProvider.new,
    );
