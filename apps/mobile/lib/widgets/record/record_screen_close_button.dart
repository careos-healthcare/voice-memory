import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-right close control for genuinely pushed Record presentations.
class RecordScreenCloseButton extends StatelessWidget {
  const RecordScreenCloseButton({super.key});

  static bool shouldShow(BuildContext context) =>
      Navigator.of(context).canPop();

  static Future<void> close(BuildContext context) async {
    final navigator = Navigator.of(context);
    final popped = await navigator.maybePop();
    if (popped || !context.mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close',
      button: true,
      child: IconButton(
        key: const Key('record_screen_close'),
        tooltip: 'Close',
        onPressed: () => close(context),
        icon: const Icon(Icons.close),
      ),
    );
  }
}
