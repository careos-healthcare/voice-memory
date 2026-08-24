import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/subscriptions/domain/subscription_models.dart';
import 'package:flutter/foundation.dart';

enum RevenueCatPlatform { ios, android, unsupported }

enum RevenueCatBuildEnvironment { development, sandbox, production }

/// Reads a compile-time or test-provided RevenueCat env value.
typedef RevenueCatEnvReader = String Function(
  String name, {
  String defaultValue,
});

/// Compile-time RevenueCat contract for consumer builds.
///
/// Only public mobile SDK keys belong here. RevenueCat secret API keys must
/// remain in server-side secret stores.
@immutable
class RevenueCatConfiguration {
  const RevenueCatConfiguration({
    required this.iosPublicSdkKey,
    required this.androidPublicSdkKey,
    required this.entitlementId,
    required this.environment,
    required this.purchasesEnabled,
    this.fallbackPublicSdkKey,
    this.monthlyProductIdentifier,
    this.yearlyProductIdentifier,
    this.offeringId,
    this.coachSeatProductIdentifier,
    this.coachSeatOfferingId,
  });

  /// Compile-time `REVENUECAT_PURCHASES_ENABLED` (default true). Config only —
  /// store billing is gated by `V1CapabilityRegistry.storeBilling`.
  static const bool purchasesEnabledAtBuildTime = bool.fromEnvironment(
    'REVENUECAT_PURCHASES_ENABLED',
    defaultValue: true,
  );
  static const bool sandboxBuild = bool.fromEnvironment(
    'REVENUECAT_SANDBOX_BUILD',
  );

  static const _iosApiKeyEnvName = 'REVENUECAT_IOS_API_KEY';
  static const _androidApiKeyEnvName = 'REVENUECAT_ANDROID_API_KEY';
  static const _fallbackApiKeyEnvName = 'REVENUECAT_API_KEY';

  /// Single-read env snapshot. SDK setup must consume this instance.
  static RevenueCatConfiguration get current => _cached ??= load();

  static RevenueCatConfiguration? _cached;

  /// Test hook — swap to spy env reads. Production uses compile-time defines.
  @visibleForTesting
  static RevenueCatEnvReader envReader = _defaultEnvReader;

  @visibleForTesting
  static void resetCacheForTest() => _cached = null;

  /// Reads the three public SDK keys once through [envReader].
  static RevenueCatConfiguration load([RevenueCatEnvReader? reader]) {
    final read = reader ?? envReader;
    return RevenueCatConfiguration(
      iosPublicSdkKey: read(_iosApiKeyEnvName),
      androidPublicSdkKey: read(_androidApiKeyEnvName),
      fallbackPublicSdkKey: read(_fallbackApiKeyEnvName),
      entitlementId: const String.fromEnvironment(
        'REVENUECAT_ENTITLEMENT_ID',
        defaultValue: ArchiveLoopEntitlementIds.archiveLoopPro,
      ),
      offeringId: const String.fromEnvironment('REVENUECAT_OFFERING_ID'),
      monthlyProductIdentifier: const String.fromEnvironment(
        'REVENUECAT_MONTHLY_PRODUCT_ID',
      ),
      yearlyProductIdentifier: const String.fromEnvironment(
        'REVENUECAT_YEARLY_PRODUCT_ID',
      ),
      coachSeatProductIdentifier: const String.fromEnvironment(
        'REVENUECAT_COACH_SEAT_PRODUCT_ID',
      ),
      coachSeatOfferingId: const String.fromEnvironment(
        'REVENUECAT_COACH_SEAT_OFFERING_ID',
      ),
      environment: sandboxBuild
          ? RevenueCatBuildEnvironment.sandbox
          : kReleaseMode
          ? RevenueCatBuildEnvironment.production
          : RevenueCatBuildEnvironment.development,
      purchasesEnabled: purchasesEnabledAtBuildTime,
    );
  }

  static String _defaultEnvReader(String name, {String defaultValue = ''}) {
    switch (name) {
      case _iosApiKeyEnvName:
        return const String.fromEnvironment(_iosApiKeyEnvName);
      case _androidApiKeyEnvName:
        return const String.fromEnvironment(_androidApiKeyEnvName);
      case _fallbackApiKeyEnvName:
        return const String.fromEnvironment(_fallbackApiKeyEnvName);
      default:
        return defaultValue;
    }
  }

  final String iosPublicSdkKey;
  final String androidPublicSdkKey;

  /// Shared public SDK key (`REVENUECAT_API_KEY`) when a platform key is empty.
  final String? fallbackPublicSdkKey;
  final String entitlementId;
  final String? offeringId;

  /// Store identifiers used to validate the current offering.
  ///
  /// They must come from build configuration. The app never substitutes
  /// fabricated production IDs when they are absent.
  final String? monthlyProductIdentifier;
  final String? yearlyProductIdentifier;
  final String? coachSeatProductIdentifier;
  final String? coachSeatOfferingId;
  final RevenueCatBuildEnvironment environment;

  /// Snapshot of `REVENUECAT_PURCHASES_ENABLED`. Does not enable store billing.
  final bool purchasesEnabled;

  String? publicSdkKeyFor(RevenueCatPlatform platform) {
    final key = switch (platform) {
      RevenueCatPlatform.ios => iosPublicSdkKey,
      RevenueCatPlatform.android => androidPublicSdkKey,
      RevenueCatPlatform.unsupported => '',
    }.trim();
    return key.isEmpty ? null : key;
  }

  /// Key passed to `Purchases.configure` — platform key, then shared fallback.
  String? sdkKeyForConfigure(RevenueCatPlatform platform) {
    final platformKey = publicSdkKeyFor(platform);
    if (platformKey != null) return platformKey;
    final fallback = fallbackPublicSdkKey?.trim() ?? '';
    return fallback.isEmpty ? null : fallback;
  }

  List<String> validationErrorsFor(RevenueCatPlatform platform) {
    if (!purchasesEnabled) return const [];
    final errors = <String>[];
    final key = publicSdkKeyFor(platform);
    final expectedPrefix = switch (platform) {
      RevenueCatPlatform.ios => 'appl_',
      RevenueCatPlatform.android => 'goog_',
      RevenueCatPlatform.unsupported => '',
    };
    if (key == null) {
      errors.add('missing_public_sdk_key');
    } else if (expectedPrefix.isEmpty || !key.startsWith(expectedPrefix)) {
      errors.add('malformed_public_sdk_key');
    }
    if (key?.startsWith('sk_') == true || key?.contains('secret') == true) {
      errors.add('secret_key_forbidden');
    }
    if (entitlementId != ArchiveLoopEntitlementIds.archiveLoopPro) {
      errors.add('unexpected_entitlement_id');
    }
    final monthlyId = _configuredProductId(monthlyProductIdentifier);
    final yearlyId = _configuredProductId(yearlyProductIdentifier);
    if (monthlyId == null) {
      errors.add('missing_monthly_product_id');
    } else if (!_validProductId(monthlyId)) {
      errors.add('invalid_monthly_product_id');
    }
    if (yearlyId == null) {
      errors.add('missing_yearly_product_id');
    } else if (!_validProductId(yearlyId)) {
      errors.add('invalid_yearly_product_id');
    }
    if (monthlyId != null && monthlyId == yearlyId) {
      errors.add('invalid_monthly_product_id');
    }
    return errors;
  }

  RevenueCatOfferingValidation validateOffers(
    List<SubscriptionOffer> offers, {
    required bool offeringExists,
  }) {
    if (!offeringExists) {
      return const RevenueCatOfferingValidation.failure(
        'missing_current_offering',
      );
    }
    final monthly = offers
        .where((offer) => offer.period == SubscriptionPeriod.monthly)
        .toList(growable: false);
    final yearly = offers
        .where((offer) => offer.period == SubscriptionPeriod.annual)
        .toList(growable: false);
    if (monthly.isEmpty) {
      return const RevenueCatOfferingValidation.failure(
        'missing_monthly_package',
      );
    }
    if (yearly.isEmpty) {
      return const RevenueCatOfferingValidation.failure(
        'missing_yearly_package',
      );
    }
    if (monthly.length != 1) {
      return const RevenueCatOfferingValidation.failure(
        'invalid_monthly_package_count',
      );
    }
    if (yearly.length != 1) {
      return const RevenueCatOfferingValidation.failure(
        'invalid_yearly_package_count',
      );
    }
    final monthlyId = _configuredProductId(monthlyProductIdentifier);
    if (monthlyId != null && monthly.single.productIdentifier != monthlyId) {
      return const RevenueCatOfferingValidation.failure(
        'monthly_product_mismatch',
      );
    }
    final yearlyId = _configuredProductId(yearlyProductIdentifier);
    if (yearlyId != null && yearly.single.productIdentifier != yearlyId) {
      return const RevenueCatOfferingValidation.failure(
        'yearly_product_mismatch',
      );
    }
    return const RevenueCatOfferingValidation.valid();
  }

  static String? _configuredProductId(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _validProductId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{5,}$').hasMatch(value);
}

@immutable
class RevenueCatOfferingValidation {
  const RevenueCatOfferingValidation.valid() : isValid = true, code = null;

  const RevenueCatOfferingValidation.failure(this.code) : isValid = false;

  final bool isValid;
  final String? code;
}

class RevenueCatOfferingConfigurationException implements Exception {
  const RevenueCatOfferingConfigurationException(this.code);

  final String code;

  @override
  String toString() => 'RevenueCatOfferingConfigurationException($code)';
}