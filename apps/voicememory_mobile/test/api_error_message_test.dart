import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/api/api_error_copy.dart';
import 'package:voicememory_mobile/api/api_error_message.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/billing/billing_async_guard.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/subscription_copy.dart';

void main() {
  test('BACKEND_NOT_CONFIGURED maps to cloud unavailable message', () {
    expect(
      userFacingErrorMessage(BackendNotConfiguredException()),
      cloudBackendUnavailableMessage,
    );
    expect(
      userFacingErrorMessage(
        ApiException(
          'Backend URL not configured',
          code: 'BACKEND_NOT_CONFIGURED',
        ),
      ),
      cloudBackendUnavailableMessage,
    );
  });

  test('ApiException toString is user-safe message only', () {
    final ex = ApiException('Sign in required.', statusCode: 401, code: 'AUTH');
    expect(ex.toString(), 'Sign in required.');
    expect(userFacingErrorMessage(ex), 'Sign in required.');
  });

  test('never surfaces ApiException wrapper text', () {
    expect(
      userFacingErrorMessage(
        ApiException('internal', statusCode: 500, code: 'INTERNAL'),
      ),
      ApiErrorCopy.genericFallback,
    );
  });

  test(
    'SocketException maps to calm copy without inspecting exception text',
    () {
      final message = userFacingErrorMessage(
        const SocketException('Connection refused'),
      );
      expect(message, isNot(contains('Connection refused')));
      expect(
        message == ApiErrorCopy.networkUnreachable ||
            message == cloudBackendUnavailableMessage ||
            message == ApiErrorCopy.localDeviceConnectionHint,
        isTrue,
      );
    },
  );

  test('TimeoutException maps to timeout copy', () {
    expect(
      userFacingErrorMessage(TimeoutException('slow')),
      ApiErrorCopy.requestTimedOut,
    );
  });

  test('BillingUnavailableException maps to subscription copy', () {
    expect(
      userFacingErrorMessage(BillingUnavailableException()),
      SubscriptionCopy.temporarilyUnavailable,
    );
  });

  test('RevenueCat PlatformException maps via PurchasesErrorCode', () {
    final cancelled = PlatformException(
      code: PurchasesErrorCode.purchaseCancelledError.index.toString(),
      message: 'Purchase was cancelled.',
    );
    expect(userFacingErrorMessage(cancelled), ApiErrorCopy.purchaseCancelled);

    final network = PlatformException(
      code: PurchasesErrorCode.networkError.index.toString(),
      message: 'Network error.',
    );
    expect(userFacingErrorMessage(network), ApiErrorCopy.networkUnreachable);

    final config = PlatformException(
      code: PurchasesErrorCode.configurationError.index.toString(),
      message: 'Invalid API key.',
    );
    expect(
      userFacingErrorMessage(config),
      SubscriptionCopy.temporarilyUnavailable,
    );
  });

  test('BillingOperationException unwraps typed causes', () {
    final message = userFacingErrorMessage(
      BillingOperationException(
        'Billing operation failed (restorePurchases)',
        cause: const SocketException('offline'),
      ),
    );
    expect(message, isNot(contains('offline')));
    expect(
      message == ApiErrorCopy.networkUnreachable ||
          message == cloudBackendUnavailableMessage,
      isTrue,
    );
    expect(
      userFacingErrorMessage(
        BillingOperationException(
          'Billing operation timed out (restorePurchases)',
        ),
      ),
      RestorePurchasesCopy.restoreError,
    );
  });

  test('unknown errors fall back to calm generic copy', () {
    expect(
      userFacingErrorMessage(StateError('RevenueCat not configured')),
      ApiErrorCopy.genericFallback,
    );
    expect(
      userFacingErrorMessage(Exception('PlatformException: internal detail')),
      ApiErrorCopy.genericFallback,
    );
  });

  test('ApiErrorCopy uses calm consumer tone without technical jargon', () {
    const banned = [
      'socket',
      'timeout',
      'timed out',
      'billing',
      'operation',
      'server',
      'request',
      'exception',
      'dart-define',
      'localhost',
      'http://',
      'lan_ip',
    ];
    final strings = [
      ApiErrorCopy.genericFallback,
      ApiErrorCopy.networkUnreachable,
      ApiErrorCopy.requestTimedOut,
      ApiErrorCopy.purchaseCancelled,
      ApiErrorCopy.signInRequired,
      ApiErrorCopy.fileTooLarge,
      ApiErrorCopy.noSpeechDetected,
      ApiErrorCopy.tooManyRequests,
      ApiErrorCopy.serviceUnavailable,
      ApiErrorCopy.localDeviceConnectionHint,
    ];
    for (final copy in strings) {
      final lower = copy.toLowerCase();
      for (final term in banned) {
        expect(
          lower,
          isNot(contains(term)),
          reason: 'ApiErrorCopy must not expose "$term" in: $copy',
        );
      }
    }
  });
}
