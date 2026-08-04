import 'package:flutter/foundation.dart';

import '../subscriptions/domain/subscription_models.dart';
import 'archive_loop_entitlement_ids.dart';

enum RevenueCatPlatform { ios, android, unsupported }

enum RevenueCatBuildEnvironment { development, sandbox, production }

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
    this.monthlyProductIdentifier,
    this.yearlyProductIdentifier,
    required this.environment,
    required this.purchasesEnabled,
    this.offeringId,
  });

  static const bool purchasesEnabledAtBuildTime = bool.fromEnvironment(
    'REVENUECAT_PURCHASES_ENABLED',
    defaultValue: true,
  );
  static const bool sandboxBuild = bool.fromEnvironment(
    'REVENUECAT_SANDBOX_BUILD',
  );

  static const RevenueCatConfiguration current = RevenueCatConfiguration(
    iosPublicSdkKey: String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
    androidPublicSdkKey: String.fromEnvironment('REVENUECAT_ANDROID_API_KEY'),
    entitlementId: String.fromEnvironment(
      'REVENUECAT_ENTITLEMENT_ID',
      defaultValue: ArchiveLoopEntitlementIds.archiveLoopPro,
    ),
    offeringId: String.fromEnvironment('REVENUECAT_OFFERING_ID'),
    monthlyProductIdentifier: String.fromEnvironment(
      'REVENUECAT_MONTHLY_PRODUCT_ID',
    ),
    yearlyProductIdentifier: String.fromEnvironment(
      'REVENUECAT_YEARLY_PRODUCT_ID',
    ),
    environment: sandboxBuild
        ? RevenueCatBuildEnvironment.sandbox
        : kReleaseMode
        ? RevenueCatBuildEnvironment.production
        : RevenueCatBuildEnvironment.development,
    purchasesEnabled: purchasesEnabledAtBuildTime,
  );

  final String iosPublicSdkKey;
  final String androidPublicSdkKey;
  final String entitlementId;
  final String? offeringId;

  /// Store identifiers used to validate the current offering.
  ///
  /// They must come from build configuration. The app never substitutes
  /// fabricated production IDs when they are absent.
  final String? monthlyProductIdentifier;
  final String? yearlyProductIdentifier;
  final RevenueCatBuildEnvironment environment;
  final bool purchasesEnabled;

  String? publicSdkKeyFor(RevenueCatPlatform platform) {
    final key = switch (platform) {
      RevenueCatPlatform.ios => iosPublicSdkKey,
      RevenueCatPlatform.android => androidPublicSdkKey,
      RevenueCatPlatform.unsupported => '',
    }.trim();
    return key.isEmpty ? null : key;
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
