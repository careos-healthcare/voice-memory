import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Test-only Dio interceptor for simulating offline mode, latency, and
/// transient HTTP failures when exercising retry logic.
///
/// Attach with [attachTo] or pass into [createNetworkSimulatedTestDio].
final class NetworkSimulatorInterceptor extends Interceptor {
  NetworkSimulatorInterceptor({
    bool offline = false,
    Duration requestDelay = Duration.zero,
    int transientFailureBudget = 0,
    int? failureStatusCode,
    DioExceptionType connectionFailureType = DioExceptionType.connectionError,
    Object? failureMessage,
  })  : _offline = offline,
        _requestDelay = requestDelay,
        _transientFailureBudget = transientFailureBudget,
        _failureStatusCode = failureStatusCode,
        _connectionFailureType = connectionFailureType,
        _failureMessage = failureMessage;

  bool _offline;
  Duration _requestDelay;
  int _transientFailureBudget;
  int? _failureStatusCode;
  DioExceptionType _connectionFailureType;
  Object? _failureMessage;

  /// Requests observed by this interceptor (success or failure).
  int requestCount = 0;

  /// Requests rejected by the simulator (offline or injected failure).
  int rejectedRequestCount = 0;

  bool get offline => _offline;

  Duration get requestDelay => _requestDelay;

  int get transientFailureBudget => _transientFailureBudget;

  int? get failureStatusCode => _failureStatusCode;

  /// Dynamically enable or disable offline simulation.
  void setOffline(bool value) {
    _offline = value;
  }

  /// Inject a fixed delay before each request proceeds.
  void setRequestDelay(Duration delay) {
    _requestDelay = delay;
  }

  /// Fail the next [count] requests, then allow subsequent requests through.
  ///
  /// When [statusCode] is omitted, failures surface as connection errors.
  /// When [statusCode] is set, failures surface as [DioExceptionType.badResponse].
  void failNextRequests(
    int count, {
    int? statusCode,
    Object? message,
  }) {
    _transientFailureBudget = count;
    _failureStatusCode = statusCode;
    if (message != null) {
      _failureMessage = message;
    }
  }

  /// Restore default pass-through behaviour and clear counters.
  void reset({
    bool offline = false,
    Duration requestDelay = Duration.zero,
    int transientFailureBudget = 0,
    int? failureStatusCode,
    DioExceptionType connectionFailureType = DioExceptionType.connectionError,
    Object? failureMessage,
    bool clearCounters = true,
  }) {
    _offline = offline;
    _requestDelay = requestDelay;
    _transientFailureBudget = transientFailureBudget;
    _failureStatusCode = failureStatusCode;
    _connectionFailureType = connectionFailureType;
    _failureMessage = failureMessage;
    if (clearCounters) {
      requestCount = 0;
      rejectedRequestCount = 0;
    }
  }

  void attachTo(Dio dio, {bool asFirstInterceptor = true}) {
    if (asFirstInterceptor) {
      dio.interceptors.insert(0, this);
    } else {
      dio.interceptors.add(this);
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    requestCount++;

    if (_offline) {
      rejectedRequestCount++;
      handler.reject(_buildFailure(options));
      return;
    }

    if (_transientFailureBudget > 0) {
      _transientFailureBudget--;
      rejectedRequestCount++;
      handler.reject(_buildFailure(options));
      return;
    }

    if (_requestDelay > Duration.zero) {
      await Future<void>.delayed(_requestDelay);
    }

    handler.next(options);
  }

  DioException _buildFailure(RequestOptions options) {
    final statusCode = _failureStatusCode;
    if (statusCode == null) {
      return DioException(
        requestOptions: options,
        type: _connectionFailureType,
        error: _failureMessage ?? 'NetworkSimulatorInterceptor: simulated offline',
        message: _failureMessage?.toString() ??
            'NetworkSimulatorInterceptor: simulated offline',
      );
    }

    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      message: _failureMessage?.toString() ??
          'NetworkSimulatorInterceptor: simulated HTTP $statusCode',
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: {
          'ok': false,
          'error': {
            'code': 'SIMULATED_FAILURE',
            'message': _failureMessage?.toString() ??
                'NetworkSimulatorInterceptor: simulated HTTP $statusCode',
          },
        },
      ),
    );
  }
}

/// Builds a [Dio] client wired for deterministic unit tests.
///
/// Uses a fixed JSON adapter so requests never hit the network unless the
/// [NetworkSimulatorInterceptor] rejects them first.
Dio createNetworkSimulatedTestDio({
  NetworkSimulatorInterceptor? simulator,
  String baseUrl = 'https://network-simulator.test',
  String responseBody = '{"ok":true,"data":{}}',
  int responseStatusCode = 200,
}) {
  final networkSimulator = simulator ?? NetworkSimulatorInterceptor();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      validateStatus: (status) => status != null && status >= 100 && status < 600,
    ),
  );
  networkSimulator.attachTo(dio);
  dio.httpClientAdapter = _FixedJsonHttpClientAdapter(
    body: responseBody,
    statusCode: responseStatusCode,
  );
  return dio;
}

final class _FixedJsonHttpClientAdapter implements HttpClientAdapter {
  _FixedJsonHttpClientAdapter({
    required this.body,
    required this.statusCode,
  });

  final String body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
