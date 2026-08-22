import 'package:archiveme_mobile/api/dio/retrofit_api_executor.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/network_simulator_interceptor.dart';

void main() {
  group('NetworkSimulatorInterceptor', () {
    late NetworkSimulatorInterceptor simulator;
    late Dio dio;

    setUp(() {
      simulator = NetworkSimulatorInterceptor();
      dio = createNetworkSimulatedTestDio(simulator: simulator);
    });

    test('passes requests through by default', () async {
      final response = await dio.get<dynamic>('/health');

      expect(response.statusCode, 200);
      expect(simulator.requestCount, 1);
      expect(simulator.rejectedRequestCount, 0);
    });

    test('setOffline rejects with connection error', () async {
      simulator.setOffline(true);

      await expectLater(
        dio.get<dynamic>('/health'),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
      expect(simulator.rejectedRequestCount, 1);

      simulator.setOffline(false);
      final response = await dio.get<dynamic>('/health');
      expect(response.statusCode, 200);
      expect(simulator.requestCount, 2);
      expect(simulator.rejectedRequestCount, 1);
    });

    test('setRequestDelay adds latency before the adapter runs', () async {
      simulator.setRequestDelay(const Duration(milliseconds: 120));

      final stopwatch = Stopwatch()..start();
      await dio.get<dynamic>('/health');
      stopwatch.stop();

      expect(stopwatch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 100)));
    });

    test('failNextRequests simulates intermittent connection failures', () async {
      simulator.failNextRequests(2);

      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          dio.get<dynamic>('/health'),
          throwsA(isA<DioException>()),
        );
      }

      final response = await dio.get<dynamic>('/health');
      expect(response.statusCode, 200);
      expect(simulator.requestCount, 3);
      expect(simulator.rejectedRequestCount, 2);
    });

    test('failNextRequests can inject retryable HTTP status codes', () async {
      simulator.failNextRequests(1, statusCode: 503, message: 'upstream unavailable');

      await expectLater(
        dio.get<dynamic>('/health'),
        throwsA(
          isA<DioException>()
              .having((error) => error.response?.statusCode, 'statusCode', 503)
              .having((error) => error.type, 'type', DioExceptionType.badResponse),
        ),
      );

      final response = await dio.get<dynamic>('/health');
      expect(response.statusCode, 200);
    });

    test('reset clears simulator configuration', () async {
      simulator
        ..setOffline(true)
        ..setRequestDelay(const Duration(seconds: 1))
        ..failNextRequests(3, statusCode: 500);

      simulator.reset();

      final response = await dio.get<dynamic>('/health');
      expect(response.statusCode, 200);
      expect(simulator.offline, isFalse);
      expect(simulator.requestDelay, Duration.zero);
      expect(simulator.transientFailureBudget, 0);
    });

    test('supports retry loops via RetrofitApiExecutor mapping', () async {
      simulator.failNextRequests(2);

      ApiFailure? lastFailure;
      var successes = 0;

      for (var attempt = 0; attempt < 3; attempt++) {
        final result = await RetrofitApiExecutor.run(() async {
          final response = await dio.get<dynamic>('/health');
          return response.statusCode;
        });
        result.when(
          success: (_) => successes++,
          onFailure: (failure) => lastFailure = failure,
        );
      }

      expect(successes, 1);
      expect(lastFailure, isA<ApiFailureOffline>());
      expect(simulator.rejectedRequestCount, 2);
    });
  });
}
