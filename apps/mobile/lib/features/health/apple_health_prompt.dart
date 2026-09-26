import 'package:archiveme_mobile/features/health/health_factory.dart';
import 'package:flutter/material.dart';

const appleHealthReadExplanation =
    'Thoughtprint can show your Apple Health State of Mind next to your moments, and save the mood you pick in Thoughtprint to Apple Health.';

const appleHealthWriteExplanation =
    'Thoughtprint saves the mood you choose to Apple Health, only if you turn this on.';

/// Shows the explanation, then asks HealthKit only after Allow.
Future<bool> confirmThenRequestAppleHealthRead(BuildContext context) async {
  final allow = await _explain(
    context,
    key: const Key('apple_health_read_explanation'),
    allowKey: const Key('apple_health_allow'),
    message: appleHealthReadExplanation,
  );
  if (!allow) return false;
  return HealthFactory.requestAuthorization();
}

/// Shows the write explanation, then asks HealthKit for an update.
Future<bool> confirmThenRequestAppleHealthWrite(BuildContext context) async {
  final allow = await _explain(
    context,
    key: const Key('apple_health_write_explanation'),
    allowKey: const Key('apple_health_write_allow'),
    message: appleHealthWriteExplanation,
  );
  if (!allow) return false;
  return HealthFactory.requestAuthorization(update: true);
}

Future<bool> _explain(
  BuildContext context, {
  required Key key,
  required Key allowKey,
  required String message,
}) async {
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: key,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        TextButton(
          key: allowKey,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  return allow ?? false;
}
