import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/billing_api_client.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

/// Server entitlement fetch with typed [ApiResult] boundaries.
class BillingRepository {
  BillingRepository({
    required this._api,
    required this._requestScope,
  });

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