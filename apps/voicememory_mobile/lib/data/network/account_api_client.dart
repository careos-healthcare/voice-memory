import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';

abstract interface class AccountApiClient {
  Future<ApiResult<void>> deleteAccount({NetworkCancelToken? cancelToken});
}
