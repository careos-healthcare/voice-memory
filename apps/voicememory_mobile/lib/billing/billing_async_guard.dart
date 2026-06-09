import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shared timeout for billing / store network calls on screen load.
const Duration billingOperationTimeout = Duration(seconds: 10);

Future<T?> withBillingTimeout<T>(
  Future<T> future, {
  required String label,
}) async {
  try {
    return await future.timeout(billingOperationTimeout);
  } on TimeoutException {
    debugPrint(
      'Billing: timeout ($label) after ${billingOperationTimeout.inSeconds}s',
    );
    return null;
  } catch (e, st) {
    debugPrint('Billing: error ($label): $e');
    if (kDebugMode) debugPrint('$st');
    return null;
  }
}
