import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelled token returns ApiFailureCancelled from transport', () async {
    final token = NetworkCancelToken()..cancel();
    final transport = HttpTransport(baseUrl: 'http://test.invalid');
    addTearDown(transport.dispose);

    final result = await transport.get('/api/health', cancelToken: token);

    expect(result.failureOrNull, isA<ApiFailureCancelled>());
  });

  test('NetworkRequestScope cancelAll cancels registered tokens', () {
    final scope = NetworkRequestScope();
    final first = scope.register();
    final second = scope.register();

    scope.cancelAll();

    expect(first.isCancelled, isTrue);
    expect(second.isCancelled, isTrue);
    expect(scope.register().isCancelled, isFalse);
  });
}