import '../../billing/paywall_source.dart';
import 'paywall_objection_copy.dart';
import 'paywall_objection_model.dart';

/// Builds paywall objection rows — display only, no billing changes.
abstract final class PaywallObjectionEngine {
  PaywallObjectionEngine._();

  static PaywallObjectionSectionResult build({
    required PaywallSource? source,
    required String surface,
  }) {
    final sourceId = source?.id ?? PaywallSource.generalPro.id;
    return PaywallObjectionSectionResult(
      shouldShow: true,
      source: sourceId,
      surface: surface,
      rows: PaywallObjectionCopy.allRows(),
      title: PaywallObjectionCopy.sectionTitle,
    );
  }
}
