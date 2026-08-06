import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shared timeout for billing / store network calls on screen load.
const Duration billingOperationTimeout = Duration(seconds: 10);

class BillingOperationException implements Exception {
  BillingOperationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

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

Future<T> withBillingTimeoutRequired<T>(
  Future<T> future, {
  required String label,
}) async {
  try {
    return await future.timeout(billingOperationTimeout);
  } on TimeoutException {
    debugPrint(
      'Billing: timeout ($label) after ${billingOperationTimeout.inSeconds}s',
    );
    throw BillingOperationException('Billing operation timed out ($label)');
  } catch (e, st) {
    debugPrint('Billing: error ($label): $e');
    if (kDebugMode) debugPrint('$st');
    if (e is BillingOperationException) rethrow;
    throw BillingOperationException(
      'Billing operation failed ($label)',
      cause: e,
    );
  }
}
