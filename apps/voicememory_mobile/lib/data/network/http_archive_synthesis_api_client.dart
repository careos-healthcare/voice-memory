import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/archive_synthesis/archive_synthesis_models.dart';
import 'archive_synthesis_api_client.dart';

class HttpArchiveSynthesisApiClient implements ArchiveSynthesisApiClient {
  HttpArchiveSynthesisApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<ArchiveSynthesisApiResponse?>> postArchiveSynthesis({
    required ArchiveSynthesisType synthesisType,
    required String monthKey,
    required String userId,
    required Map<String, dynamic> pack,
    int? milestoneThreshold,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri('/api/archive-synthesis') == null) {
      return const ApiSuccess(null);
    }

    final responseResult = await _transport.post(
      '/api/archive-synthesis',
      body: {
        'synthesisType': synthesisType.apiValue,
        'monthKey': monthKey,
        'userId': userId,
        'pack': pack,
        if (milestoneThreshold != null)
          'milestoneThreshold': milestoneThreshold,
      },
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 403) {
          return const ApiSuccess(null);
        }
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }

        return _transport.decodeSuccess(response, (body) {
          final type =
              body['synthesisType']?.toString() ?? synthesisType.apiValue;
          final reviewJson = body['review'];
          if (reviewJson is! Map) return null;
          final map = Map<String, dynamic>.from(reviewJson);

          return ArchiveSynthesisApiResponse(
            synthesisType: type,
            cached: body['cached'] == true,
            monthlyReview: type == 'monthly'
                ? ArchiveMonthlyReview.fromJson(map)
                : null,
            milestoneReview: type == 'milestone'
                ? ArchiveMilestoneReview.fromJson(map)
                : null,
            deepDiveNarrative: type == 'deep_dive'
                ? ArchiveDeepDiveNarrative.fromJson(map)
                : null,
            historianReport: type == 'historian'
                ? ArchiveHistorianReport.fromJson(map)
                : null,
          );
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
