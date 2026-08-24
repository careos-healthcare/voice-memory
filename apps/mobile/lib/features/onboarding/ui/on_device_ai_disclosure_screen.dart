import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation_copy.dart';
import 'package:flutter/material.dart';

/// Last onboarding disclosure before `/record`.
///
/// [onContinue] proceeds into the app. It does not grant remote-processing
/// consent — that decision is recorded on the previous step.
/// [onCancel] returns to that previous step. It is not a consent decline.
class OnDeviceAiDisclosureScreen extends StatelessWidget {
  const OnDeviceAiDisclosureScreen({
    required this.onContinue,
    required this.onCancel,
    super.key,
    this.submitting = false,
  });

  final VoidCallback onContinue;
  final VoidCallback onCancel;
  final bool submitting;

  static const Key screenKey = Key('on_device_ai_disclosure_screen');
  static const Key titleKey = Key('on_device_ai_disclosure_screen_title');
  static const Key bodyKey = Key('on_device_ai_disclosure_screen_body');
  static const Key continueKey = Key('on_device_ai_disclosure_screen_continue');
  static const Key cancelKey = Key('on_device_ai_disclosure_screen_cancel');
  static const Key shieldKey = Key('on_device_ai_disclosure_screen_shield');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      key: screenKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              key: shieldKey,
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield,
                size: 52,
                color: Colors.lightBlue.shade700,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              OnDeviceAiDisclosureCopy.heading,
              key: titleKey,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: onSurface,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              OnDeviceAiDisclosureCopy.body,
              key: bodyKey,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: secondary,
                height: 1.5,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: continueKey,
                onPressed: submitting ? null : onContinue,
                child: const Text(OnDeviceAiDisclosureCopy.understandCta),
              ),
            ),
            TextButton(
              key: cancelKey,
              onPressed: submitting ? null : onCancel,
              child: const Text(OnDeviceAiDisclosureCopy.cancelCta),
            ),
          ],
        ),
      ),
    );
  }
}
