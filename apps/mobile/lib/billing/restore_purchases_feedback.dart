import 'package:archiveme_mobile/billing/restore_purchases_flow.dart';
import 'package:flutter/material.dart';

/// Visible restore outcome feedback — never silent after restore completes.
abstract final class RestorePurchasesFeedback {
  static const snackBarDuration = Duration(seconds: 5);

  /// User-visible copy for [result], or null when nothing should be shown.
  static String? messageFor(RestorePurchasesResult result) {
    if (result.outcome == RestorePurchasesOutcome.skippedBusy) return null;
    final message = result.userMessage;
    return message.isEmpty ? null : message;
  }

  static void showSnackBar(
    BuildContext context,
    RestorePurchasesResult result,
  ) {
    final message = messageFor(result);
    if (message == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: snackBarDuration,
          behavior: SnackBarBehavior.floating,
          // Sit above pushed-screen bottom chrome (Done button).
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
  }
}