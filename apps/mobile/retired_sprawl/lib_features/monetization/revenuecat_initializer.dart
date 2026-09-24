import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Debug, sandbox, and production builds each supply their own public SDK key.
enum RevenueCatRuntimeEnvironment { debug, sandbox, production }

/// Configures `purchases_flutter` once per process.
abstract final class RevenueCatInitializer {
  RevenueCatInitializer._();

  static RevenueCatRuntimeEnvironment currentEnvironment() {
    if (const bool.fromEnvironment('REVENUECAT_SANDBOX_BUILD')) {
      return RevenueCatRuntimeEnvironment.sandbox;
    }
    if (kReleaseMode) return RevenueCatRuntimeEnvironment.production;
    return RevenueCatRuntimeEnvironment.debug;
  }

  /// Public SDK key for [environment]. Secret `sk_` keys are rejected.
  static String? publicApiKey({
    required RevenueCatRuntimeEnvironment environment,
    bool? ios,
    bool? android,
    String debugKey = const String.fromEnvironment('REVENUECAT_DEBUG_API_KEY'),
    String sandboxKey = const String.fromEnvironment(
      'REVENUECAT_SANDBOX_API_KEY',
    ),
    String productionKey = const String.fromEnvironment(
      'REVENUECAT_PRODUCTION_API_KEY',
    ),
    String iosKey = const String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
    String androidKey = const String.fromEnvironment(
      'REVENUECAT_ANDROID_API_KEY',
    ),
    String fallbackKey = const String.fromEnvironment('REVENUECAT_API_KEY'),
  }) {
    final selected = switch (environment) {
      RevenueCatRuntimeEnvironment.debug => debugKey,
      RevenueCatRuntimeEnvironment.sandbox => sandboxKey,
      RevenueCatRuntimeEnvironment.production => productionKey,
    }.trim();
    if (selected.isNotEmpty) return _publicKey(selected);

    final onIos = ios ?? Platform.isIOS;
    final onAndroid = android ?? Platform.isAndroid;
    if (onIos && iosKey.trim().isNotEmpty) return _publicKey(iosKey.trim());
    if (onAndroid && androidKey.trim().isNotEmpty) {
      return _publicKey(androidKey.trim());
    }
    if (fallbackKey.trim().isNotEmpty) return _publicKey(fallbackKey.trim());
    return null;
  }

  /// Calls [Purchases.configure] only when the SDK is not already configured.
  static Future<bool> ensureConfigured({
    String? apiKey,
    RevenueCatRuntimeEnvironment? environment,
    bool? ios,
    bool? android,
    Duration timeout = const Duration(seconds: 10),
    Future<bool> Function()? readConfigured,
    Future<void> Function(PurchasesConfiguration configuration)? configure,
  }) async {
    if (await _isConfigured(readConfigured)) return true;
    final key =
        (apiKey ??
                publicApiKey(
                  environment: environment ?? currentEnvironment(),
                  ios: ios,
                  android: android,
                ))
            ?.trim();
    if (key == null || key.isEmpty) return false;
    try {
      final apply = configure ?? Purchases.configure;
      await apply(PurchasesConfiguration(key)).timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }

  static Future<bool> _isConfigured(Future<bool> Function()? read) async {
    try {
      final probe = read ?? () => Purchases.isConfigured;
      return await probe();
    } on Object {
      return false;
    }
  }

  static String? _publicKey(String key) {
    if (key.startsWith('sk_')) return null;
    return key;
  }
}
