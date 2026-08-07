import 'package:http/http.dart' as http;

import '../../api/api_exceptions.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/sync/journal_pull_paginator.dart';
import '../../models/journal_entry.dart';
import 'sync_api_client.dart';

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient(this._transport);

  final HttpTransport _transport;

  static const _journalPullPageSize = 500;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    final responseResult = await _transport.get('/api/sync/manifest');
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    final responseResult = await _transport.get('/api/sync/pull');
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    final responseResult = await _transport.get(
      '/api/sync/changes',
      queryParameters: {'since': '$since'},
    );
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    final responseResult = await _transport.post('/api/sync/push', body: body);
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  }) async {
    final paginator = JournalPullPaginator();
    final all = <JournalEntry>[];
    String? cursor;

    while (true) {
      final query = <String, String>{'limit': '$_journalPullPageSize'};
      if (cursor != null) query['cursor'] = cursor;

      final responseResult = await _transport.get(
        '/api/journal',
        queryParameters: query,
        cancelToken: cancelToken,
      );

      if (responseResult case ApiFailureResult(:final failure)) {
        return ApiFailureResult(failure);
      }

      final response = (responseResult as ApiSuccess<http.Response>).value;
      if (response.statusCode == 401) {
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      }

      final decoded = _transport.decodeSuccess(response, (body) {
        final entries = body['entries'] as List<dynamic>? ?? [];
        final nextCursor = body['nextCursor'] as String?;
        final result = paginator.ingestPage(
          rawEntries: entries,
          nextCursor: nextCursor,
          currentCursor: cursor,
        );
        if (result is JournalPullPageAborted) {
          throw ApiException(
            'Journal pull aborted: ${result.reason}',
            statusCode: 400,
            code: 'JOURNAL_PULL_ABORTED',
          );
        }
        final accepted = result as JournalPullPageAccepted;
        return (accepted.entries, accepted.nextCursor);
      });

      if (decoded case ApiFailureResult(:final failure)) {
        return ApiFailureResult(failure);
      }

      final (entries, nextCursor) =
          (decoded as ApiSuccess<(List<JournalEntry>, String?)>).value;
      all.addAll(entries);
      cursor = nextCursor;
      if (cursor == null) break;
    }

    return ApiSuccess(all);
  }

  ApiResult<Map<String, dynamic>> _decodeObject(
    ApiResult<http.Response> responseResult,
  ) {
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _transport.decodeSuccess(response, (json) => json);
        }
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
