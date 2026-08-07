import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/archive_synthesis/archive_synthesis_models.dart';
import '../network/archive_synthesis_api_client.dart';

class ArchiveSynthesisRepository {
  ArchiveSynthesisRepository({
    required ArchiveSynthesisApiClient api,
    required NetworkRequestScope requestScope,
  }) : _api = api,
       _requestScope = requestScope;

  final ArchiveSynthesisApiClient _api;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<ArchiveSynthesisApiResponse?>> postArchiveSynthesis({
    required ArchiveSynthesisType synthesisType,
    required String monthKey,
    required String userId,
    required Map<String, dynamic> pack,
    int? milestoneThreshold,
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      return await _api.postArchiveSynthesis(
        synthesisType: synthesisType,
        monthKey: monthKey,
        userId: userId,
        pack: pack,
        milestoneThreshold: milestoneThreshold,
        cancelToken: token,
      );
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }
}
