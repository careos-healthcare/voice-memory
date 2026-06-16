import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-right close control for Record on tablet layouts and modal presentations.
class RecordScreenCloseButton extends StatelessWidget {
  const RecordScreenCloseButton({super.key});

  static const double tabletMinWidth = 600;

  static bool shouldShow(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= tabletMinWidth;
    final canPop = Navigator.of(context).canPop();
    return isTablet || canPop;
  }

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
