import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../models/entitlement.dart';
import '../network/billing_api_client.dart';

/// Server entitlement fetch with typed [ApiResult] boundaries.
class BillingRepository {
  BillingRepository({
    required BillingApiClient api,
    required NetworkRequestScope requestScope,
  }) : _api = api,
       _requestScope = requestScope;

  final BillingApiClient _api;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<PremiumEntitlements>> fetchEntitlements() async {
    final token = _requestScope.register();
    try {
      return await _api.getEntitlements(cancelToken: token);
    } finally {
      _requestScope.release(token);
    }
  }
}
