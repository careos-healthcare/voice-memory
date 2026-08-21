import 'package:archiveme_mobile/api/models/billing_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_billing_api.g.dart';

@RestApi()
abstract class VoiceMemoryBillingApi {
  factory VoiceMemoryBillingApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryBillingApi;

  @GET('/api/billing/entitlements')
  Future<BillingEntitlementsApiResponse> getEntitlements();

  @POST('/api/billing/checkout')
  Future<BillingCheckoutApiResponse> createCheckout();
}