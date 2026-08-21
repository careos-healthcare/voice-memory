import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';

abstract interface class AccountApiClient {
  Future<ApiResult<void>> deleteAccount({NetworkCancelToken? cancelToken});
}