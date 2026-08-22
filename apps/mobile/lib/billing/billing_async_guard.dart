import 'dart:async';

import 'package:archiveme_mobile/billing/billing_async_guard_log.dart';

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
    BillingAsyncGuardLog.timeout(
      label: label,
      timeoutSeconds: billingOperationTimeout.inSeconds,
    );
    return null;
  } catch (e, stackTrace) {
    BillingAsyncGuardLog.error(label: label, error: e, stackTrace: stackTrace);
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
    BillingAsyncGuardLog.timeout(
      label: label,
      timeoutSeconds: billingOperationTimeout.inSeconds,
    );
    throw BillingOperationException('Billing operation timed out ($label)');
  } catch (e, stackTrace) {
    BillingAsyncGuardLog.error(label: label, error: e, stackTrace: stackTrace);
    if (e is BillingOperationException) rethrow;
    throw BillingOperationException(
      'Billing operation failed ($label)',
      cause: e,
    );
  }
}