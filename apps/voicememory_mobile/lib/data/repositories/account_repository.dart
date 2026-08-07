import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../core/network/session_cookie_source.dart';
import '../network/account_api_client.dart';

class AccountRepository {
  AccountRepository({
    required AccountApiClient api,
    required SessionCookieSource sessionCookies,
    required NetworkRequestScope requestScope,
  }) : _api = api,
       _sessionCookies = sessionCookies,
       _requestScope = requestScope;

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
