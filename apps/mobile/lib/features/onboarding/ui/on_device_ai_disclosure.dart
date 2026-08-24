import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_disclosure_screen.dart';
import 'package:flutter/material.dart';

export 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_disclosure_screen.dart';

/// Canonical on-device AI disclosure — the first onboarding page.
///
/// Builds [OnDeviceAiDisclosureScreen]. [onContinue] advances into welcome;
/// it does not mark onboarding complete and does not grant remote-processing
/// consent. [onCancel] is hidden when this is the first page ([showCancel]
/// false). Standalone pumps keep Cancel.
class OnDeviceAiDisclosure extends StatelessWidget {
  const OnDeviceAiDisclosure({
    required this.onContinue,
    required this.onCancel,
    super.key,
    this.submitting = false,
    this.onSeeDetails,
    this.showCancel = true,
  });

  final VoidCallback onContinue;
  final VoidCallback onCancel;
  final bool submitting;
  final bool showCancel;

  /// Kept so callers that passed a privacy-details override still compile.
  final VoidCallback? onSeeDetails;

  static const Key screenKey = Key('on_device_ai_disclosure');

  /// Backward-compatible key used by the OnDeviceAiExplanation alias.
  static const Key explanationKey = Key('on_device_ai_explanation');

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: screenKey,
      child: KeyedSubtree(
        key: explanationKey,
        child: OnDeviceAiDisclosureScreen(
          onContinue: onContinue,
          onCancel: onCancel,
          submitting: submitting,
          showCancel: showCancel,
        ),
      ),
    );
  }
}
