import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/api_failure_mapper.dart';

void main() {
  group('ApiFailureMapper.fromResponse', () {
    test('maps 401 to auth required', () {
      final failure = ApiFailureMapper.fromResponse(
        http.Response(
          jsonEncode({'error': 'Sign in first', 'code': 'AUTH_REQUIRED'}),
          401,
        ),
      );
      expect(failure, isA<ApiFailureAuthRequired>());
      expect(failure.code, 'AUTH_REQUIRED');
    });

    test('maps HTML responses to invalid response', () {
      final failure = ApiFailureMapper.fromResponse(
        http.Response('<html><body>nginx</body></html>', 200, headers: {
          'content-type': 'text/html',
        }),
      );
      expect(failure, isA<ApiFailureInvalidResponse>());
    });

    test('maps 429 to rate limited', () {
      final failure = ApiFailureMapper.fromResponse(
        http.Response(jsonEncode({'error': 'Slow down'}), 429),
      );
      expect(failure, isA<ApiFailureRateLimited>());
    });
  });

  group('ApiFailureMapper.fromException', () {
    test('maps socket errors to offline', () {
      final failure = ApiFailureMapper.fromException(
        const SocketException('Connection refused'),
      );
      expect(failure, isA<ApiFailureOffline>());
    });

    test('maps ApiException to typed failure', () {
      final failure = ApiFailureMapper.fromException(
        AuthRequiredException('Sign in to continue.'),
      );
      expect(failure, isA<ApiFailureAuthRequired>());
    });
  });
}
