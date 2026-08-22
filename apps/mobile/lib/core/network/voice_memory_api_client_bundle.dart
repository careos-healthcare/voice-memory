import 'package:archiveme_mobile/api/dio/session_cookie_capture.dart';
import 'package:archiveme_mobile/api/dio/voice_memory_dio_factory.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_retrofit_client.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/session_cookie_source.dart';
import 'package:archiveme_mobile/data/network/account_api_client.dart';
import 'package:archiveme_mobile/data/network/archive_synthesis_api_client.dart';
import 'package:archiveme_mobile/data/network/auth_api_client.dart';
import 'package:archiveme_mobile/data/network/billing_api_client.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/coach_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/http_account_api_client.dart';
import 'package:archiveme_mobile/data/network/http_archive_synthesis_api_client.dart';
import 'package:archiveme_mobile/data/network/http_auth_api_client.dart';
import 'package:archiveme_mobile/data/network/http_billing_api_client.dart';
import 'package:archiveme_mobile/data/network/http_capture_api_client.dart';
import 'package:archiveme_mobile/data/network/http_caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/http_coach_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/http_live_audio_api_client.dart';
import 'package:archiveme_mobile/data/network/http_push_api_client.dart';
import 'package:archiveme_mobile/data/network/http_sync_api_client.dart';
import 'package:archiveme_mobile/data/network/http_user_relationship_api_client.dart';
import 'package:archiveme_mobile/data/network/live_audio_api_client.dart';
import 'package:archiveme_mobile/data/network/push_api_client.dart';
import 'package:archiveme_mobile/data/network/retrofit_auth_api_client.dart';
import 'package:archiveme_mobile/data/network/retrofit_billing_api_client.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/data/network/user_relationship_api_client.dart';
import 'package:archiveme_mobile/services/api_service.dart';
import 'package:dio/dio.dart';

/// Type-safe facade over all domain HTTP clients sharing one [HttpTransport].
class VoiceMemoryApiClientBundle {
  VoiceMemoryApiClientBundle._({
    required this.transport,
    required this.auth,
    required this.sync,
    required this.billing,
    required this.capture,
    required this.archiveSynthesis,
    required this.account,
    required this.push,
    required this.liveAudio,
    required this.coachConsent,
    required this.caregiverConsent,
    required this.userRelationships,
    required this.insights,
    Dio? retrofitDio,
    this.sessionCookieCapture,
  }) : _retrofitDio = retrofitDio;

  final HttpTransport transport;
  final AuthApiClient auth;
  final SyncApiClient sync;
  final BillingApiClient billing;
  final CaptureApiClient capture;
  final ArchiveSynthesisApiClient archiveSynthesis;
  final AccountApiClient account;
  final PushApiClient push;
  final LiveAudioApiClient liveAudio;
  final CoachConsentApiClient coachConsent;
  final CaregiverConsentApiClient caregiverConsent;
  final UserRelationshipApiClient userRelationships;
  final ApiService insights;
  final SessionCookieCapture? sessionCookieCapture;

  final Dio? _retrofitDio;

  factory VoiceMemoryApiClientBundle.fromTransport(
    HttpTransport transport, {
    required SessionCookieSource sessionCookies,
  }) {
    final capture = SessionCookieCapture();
    final dio = tryCreateVoiceMemoryDio(
      baseUrl: AppConfig.apiBaseUrl,
      sessionCookies: sessionCookies,
      sessionCookieCapture: capture,
    );
    if (dio != null) {
      final retrofit = VoiceMemoryRetrofitClient.fromDio(dio);
      return VoiceMemoryApiClientBundle._(
        transport: transport,
        auth: RetrofitAuthApiClient(
          retrofit.auth,
          sessionCookieCapture: capture,
        ),
        sync: HttpSyncApiClient(transport),
        billing: RetrofitBillingApiClient(retrofit.billing),
        capture: HttpCaptureApiClient(transport),
        archiveSynthesis: HttpArchiveSynthesisApiClient(transport),
        account: HttpAccountApiClient(transport),
        push: HttpPushApiClient(transport),
        liveAudio: HttpLiveAudioApiClient(transport),
        coachConsent: HttpCoachConsentApiClient(transport),
        caregiverConsent: HttpCaregiverConsentApiClient(transport),
        userRelationships: HttpUserRelationshipApiClient(transport),
        insights: ApiService(transport),
        retrofitDio: dio,
        sessionCookieCapture: capture,
      );
    }

    return VoiceMemoryApiClientBundle._(
      transport: transport,
      auth: HttpAuthApiClient(transport),
      sync: HttpSyncApiClient(transport),
      billing: HttpBillingApiClient(transport),
      capture: HttpCaptureApiClient(transport),
      archiveSynthesis: HttpArchiveSynthesisApiClient(transport),
      account: HttpAccountApiClient(transport),
      push: HttpPushApiClient(transport),
      liveAudio: HttpLiveAudioApiClient(transport),
      coachConsent: HttpCoachConsentApiClient(transport),
      caregiverConsent: HttpCaregiverConsentApiClient(transport),
      userRelationships: HttpUserRelationshipApiClient(transport),
      insights: ApiService(transport),
    );
  }

  void dispose() {
    _retrofitDio?.close(force: true);
  }
}
