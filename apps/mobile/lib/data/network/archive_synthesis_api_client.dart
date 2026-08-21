import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';

abstract interface class ArchiveSynthesisApiClient {
  Future<ApiResult<ArchiveSynthesisApiResponse?>> postArchiveSynthesis({
    required ArchiveSynthesisType synthesisType,
    required String monthKey,
    required String userId,
    required Map<String, dynamic> pack,
    int? milestoneThreshold,
    NetworkCancelToken? cancelToken,
  });
}