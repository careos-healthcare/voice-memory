import 'paywall_source.dart';
import 'paywall_trigger_model.dart';
import 'pro_value_preview_engine.dart';
import 'pro_value_preview_model.dart';

/// Optional paywall context passed via GoRouter [extra].
class PaywallRouteArgs {
  const PaywallRouteArgs({
    this.trigger,
    this.previewTitle,
    this.previewBody,
    this.sourceRoute,
    this.valuePreview,
    this.source,
  });

  final PaywallTrigger? trigger;
  final String? previewTitle;
  final String? previewBody;
  final String? sourceRoute;
  final ProValuePreview? valuePreview;

  /// Which surface opened the paywall; drives source-aware headline copy.
  final PaywallSource? source;

  factory PaywallRouteArgs.fromContext(PaywallTriggerContext context) {
    final preview = buildProValuePreview(context);
    return PaywallRouteArgs(
      trigger: context.trigger,
      previewTitle: preview.title,
      previewBody: preview.body,
      sourceRoute: context.sourceRoute,
      valuePreview: preview,
    );
  }

  bool get hasTriggerCopy =>
      previewTitle != null &&
      previewTitle!.trim().isNotEmpty &&
      previewBody != null &&
      previewBody!.trim().isNotEmpty;
}
