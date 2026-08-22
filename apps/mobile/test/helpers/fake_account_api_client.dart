import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/account_api_client.dart';

class FakeAccountApiClient implements AccountApiClient {
  FakeAccountApiClient();

  int deleteAccountCalls = 0;
  ApiFailure? deleteAccountFailure;

  @override
  Future<ApiResult<void>> deleteAccount({
    NetworkCancelToken? cancelToken,
  }) async {
    deleteAccountCalls++;
    final failure = deleteAccountFailure;
    if (failure != null) {
      return ApiFailureResult(failure);
    }
    return const ApiSuccess(null);
  }
}