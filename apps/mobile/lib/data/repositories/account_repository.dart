import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/session_cookie_source.dart';
import 'package:archiveme_mobile/data/network/account_api_client.dart';

class AccountRepository {
  AccountRepository({
    required this._api,
    required this._sessionCookies,
    required this._requestScope,
  });

  final AccountApiClient _api;
  final SessionCookieSource _sessionCookies;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<void>> deleteAccount({
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      final result = await _api.deleteAccount(cancelToken: token);
      if (result case ApiSuccess()) {
        await _sessionCookies.clear(persist: false);
      }
      return result;
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }
}