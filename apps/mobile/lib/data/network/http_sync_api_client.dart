import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/features/sync/journal_pull_paginator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:http/http.dart' as http;

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient(this._transport);

  final HttpTransport _transport;

  static const _journalPullPageSize = 500;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    final responseResult = await _transport.get(VoiceMemoryApiRoutes.syncManifest.path);
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    final responseResult = await _transport.get(VoiceMemoryApiRoutes.syncPull.path);
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    final responseResult = await _transport.get(
      VoiceMemoryApiRoutes.syncChanges.path,
      queryParameters: {'since': '$since'},
    );
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    final responseResult = await _transport.post(VoiceMemoryApiRoutes.syncPush.path, body: body);
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
        VoiceMemoryApiRoutes.journal.path,
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

      final decoded = _transport.decodeEnvelope<Map<String, dynamic>, (List<JournalEntry>, String?)>(
        response,
        parseData: (json) => json,
        toDomain: (body) {
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
        },
        missingDataMessage: 'Journal page payload missing',
      );

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
          return _transport.decodeEnvelope(
            response,
            parseData: (json) => json,
            toDomain: (json) => json,
          );
        }
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
