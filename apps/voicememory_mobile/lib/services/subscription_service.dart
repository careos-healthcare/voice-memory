import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/billing_api_client.dart';
import '../config/app_feature_flags.dart';
import '../subscriptions/domain/subscription_repository.dart';

typedef ExternalCheckoutLauncher = Future<bool> Function(Uri uri);

/// Server-verified Stripe subscription status and policy-gated web checkout.
///
/// Native store billing remains available through [SubscriptionRepository].
/// This service exposes an external browser only when both the global feature
/// flag and the platform-specific compliance flag permit it.
class SubscriptionService {
  SubscriptionService(
    this._api, {
    ExternalCheckoutLauncher? launchExternal,
    bool? useWebCheckout,
    bool? allowIosWebCheckout,
    bool? allowAndroidWebCheckout,
  }) : _launchExternal =
           launchExternal ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _useWebCheckout = useWebCheckout ?? AppFeatureFlags.useWebStripeCheckout,
       _allowIosWebCheckout =
           allowIosWebCheckout ?? AppFeatureFlags.allowIosWebStripeCheckout,
       _allowAndroidWebCheckout =
           allowAndroidWebCheckout ??
           AppFeatureFlags.allowAndroidWebStripeCheckout;

  final BillingApiClient _api;
  final ExternalCheckoutLauncher _launchExternal;
  final bool _useWebCheckout;
  final bool _allowIosWebCheckout;
  final bool _allowAndroidWebCheckout;

  bool get canOfferWebCheckout {
    if (!_useWebCheckout) return false;
    if (kIsWeb) return true;
    if (Platform.isIOS) return _allowIosWebCheckout;
    if (Platform.isAndroid) return _allowAndroidWebCheckout;
    return true;
  }

  Future<bool> hasActiveSubscription() async =>
      (await _api.getSubscriptionStatus()).hasActiveSubscription;

  Future<Uri> createCheckoutUri() async {
    if (!canOfferWebCheckout) {
      throw StateError(
        'External checkout is not enabled for this distribution channel.',
      );
    }
    final checkout = await _api.createCheckoutSession();
    final uri = Uri.tryParse(checkout.url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Checkout URL must use HTTPS.');
    }
    return uri;
  }

  Future<bool> openCheckout() async {
    final uri = await createCheckoutUri();
    return _launchExternal(uri);
  }
}
