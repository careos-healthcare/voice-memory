import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:flutter/material.dart';

/// Canonical on-device AI disclosure — the last onboarding step before
/// `/record`.
///
/// Named alias of [OnDeviceHeroScreen], not a fifth page. The hero already
/// occupies "before first record / before dashboard"; this name is what the
/// product brief asked for without restating the same claims twice.
class OnDeviceAiDisclosure extends StatelessWidget {
  const OnDeviceAiDisclosure({
    required this.onContinue,
    super.key,
    this.submitting = false,
    this.onSeeDetails,
  });

  final VoidCallback onContinue;
  final bool submitting;
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
        child: OnDeviceHeroScreen(
          onContinue: onContinue,
          submitting: submitting,
          onSeeDetails: onSeeDetails,
        ),
      ),
    );
  }
}
