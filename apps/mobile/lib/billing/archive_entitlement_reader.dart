import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Reads whether the user has ArchiveMe Pro — injectable for tests.
abstract class ArchiveEntitlementReader {
  const ArchiveEntitlementReader();

  Future<bool> get isPro;

  static ArchiveEntitlementReader instance() => _LiveArchiveEntitlementReader();

  /// Trial builds skip paywall gates so facilitators can test the full loop.
  static ArchiveEntitlementReader forAccessCheck() {
    if (!V1BillingCapability.isProductionReachable) {
      return const _ProArchiveEntitlementReader();
    }
    if (TrialMode.enabled) return const _ProArchiveEntitlementReader();
    return instance();
  }
}

class _LiveArchiveEntitlementReader extends ArchiveEntitlementReader {
  @override
  Future<bool> get isPro async {
    if (!AppServices.isInitialized) return false;
    final ent = await AppServices.instance.billing.loadEntitlements();
    return ent.isPro;
  }
}

class _ProArchiveEntitlementReader extends ArchiveEntitlementReader {
  const _ProArchiveEntitlementReader();

  @override
  Future<bool> get isPro async => true;
}

/// Fixed entitlement for widget tests.
class FakeArchiveEntitlementReader extends ArchiveEntitlementReader {
  FakeArchiveEntitlementReader({required this.pro});

  final bool pro;

  @override
  Future<bool> get isPro async => pro;
}

extension PremiumEntitlementsPro on PremiumEntitlements {
  bool get archiveProAccess => isPro;
}