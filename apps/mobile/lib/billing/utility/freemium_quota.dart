import 'package:archiveme_mobile/billing/utility/entitlement_required_exception.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Free cloud answers and on-device media before a Pro utility is required.
@immutable
class FreemiumQuota {
  const FreemiumQuota({
    this.cloudTokensUsed = 0,
    this.mediaBytesUsed = 0,
    this.isPro = false,
    this.billingReachable = V1BillingCapability.isProductionReachable,
  });

  static const int freeCloudTokens = 20;
  static const int freeMediaBytes = 500 * 1024 * 1024;

  final int cloudTokensUsed;
  final int mediaBytesUsed;
  final bool isPro;
  final bool billingReachable;

  int get cloudTokensRemaining => _remaining(freeCloudTokens, cloudTokensUsed);

  int get mediaBytesRemaining => _remaining(freeMediaBytes, mediaBytesUsed);

  /// 1 means the full free allowance is still available.
  double get tokenFractionRemaining =>
      isPro ? 1 : cloudTokensRemaining / freeCloudTokens;

  double get storageFractionRemaining =>
      isPro ? 1 : mediaBytesRemaining / freeMediaBytes;

  static int _remaining(int cap, int used) {
    final remaining = cap - used;
    if (remaining < 0) return 0;
    if (remaining > cap) return cap;
    return remaining;
  }

  FreemiumQuota copyWith({
    int? cloudTokensUsed,
    int? mediaBytesUsed,
    bool? isPro,
    bool? billingReachable,
  }) {
    return FreemiumQuota(
      cloudTokensUsed: cloudTokensUsed ?? this.cloudTokensUsed,
      mediaBytesUsed: mediaBytesUsed ?? this.mediaBytesUsed,
      isPro: isPro ?? this.isPro,
      billingReachable: billingReachable ?? this.billingReachable,
    );
  }
}

class FreemiumQuotaController extends Notifier<FreemiumQuota> {
  @override
  FreemiumQuota build() => const FreemiumQuota();

  set snapshot(FreemiumQuota quota) => state = quota;

  void consumeCloudToken() {
    state = state.copyWith(cloudTokensUsed: state.cloudTokensUsed + 1);
  }

  void addMedia(int bytes) {
    state = state.copyWith(mediaBytesUsed: state.mediaBytesUsed + bytes);
  }
}

final freemiumQuotaProvider =
    NotifierProvider<FreemiumQuotaController, FreemiumQuota>(
      FreemiumQuotaController.new,
    );

/// Entitlement checks for export, cloud answers, and media over 500 MB.
///
/// Creating an entry and searching on device always succeed.
class UtilityEntitlementGate {
  UtilityEntitlementGate(
    this._read, {
    this.consumeToken,
    this.addMedia,
  });

  final FreemiumQuota Function() _read;
  final void Function()? consumeToken;
  final void Function(int bytes)? addMedia;

  FreemiumQuota get quota => _read();

  bool canCreateEntry() => true;

  bool canSearchLocally() => true;

  bool get _unlimited => quota.isPro || !quota.billingReachable;

  bool canExportArchive() => _unlimited;

  bool canUseCloudLLM() => _unlimited || quota.cloudTokensRemaining > 0;

  bool canUploadMedia(int bytes) {
    if (bytes < 0) return false;
    if (_unlimited) return true;
    return quota.mediaBytesUsed + bytes <= FreemiumQuota.freeMediaBytes;
  }

  void requireExport() {
    if (!canExportArchive()) {
      throw const EntitlementRequiredException(UtilityLimit.exportArchive);
    }
  }

  void requireCloudLlm() {
    if (!canUseCloudLLM()) {
      throw const EntitlementRequiredException(UtilityLimit.cloudLlm);
    }
    if (!_unlimited) consumeToken?.call();
  }

  void requireMediaUpload(int bytes) {
    if (!canUploadMedia(bytes)) {
      throw const EntitlementRequiredException(UtilityLimit.mediaStorage);
    }
    if (!_unlimited && bytes > 0) addMedia?.call(bytes);
  }
}

final utilityEntitlementGateProvider = Provider<UtilityEntitlementGate>((ref) {
  return UtilityEntitlementGate(
    () => ref.read(freemiumQuotaProvider),
    consumeToken: () =>
        ref.read(freemiumQuotaProvider.notifier).consumeCloudToken(),
    addMedia: (bytes) =>
        ref.read(freemiumQuotaProvider.notifier).addMedia(bytes),
  );
});

/// Runs one cloud expansion after the free-token check.
Future<T> expandWithCloudLlm<T>({
  required UtilityEntitlementGate gate,
  required Future<T> Function() expand,
}) async {
  gate.requireCloudLlm();
  return expand();
}
