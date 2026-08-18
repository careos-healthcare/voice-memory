import 'package:archiveme_mobile/api/retrofit/voice_memory_auth_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_insights_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_sync_api.dart';
import 'package:archiveme_mobile/api/dio/voice_memory_dio_factory.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_retrofit_client.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared [Dio] instance for Retrofit clients — base URL from bootstrap injection.
final voiceMemoryDioProvider = Provider<Dio>((ref) {
  final dio = createVoiceMemoryDio(
    baseUrl: ref.watch(voiceMemoryApiBaseUrlProvider),
    sessionCookies: ref.watch(sessionCookieSourceProvider),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Parallel type-safe client (Dio + Retrofit) alongside [voiceMemoryApiClientBundleProvider].
final voiceMemoryRetrofitClientProvider = Provider<VoiceMemoryRetrofitClient>(
  (ref) => VoiceMemoryRetrofitClient.fromDio(ref.watch(voiceMemoryDioProvider)),
);

final voiceMemoryAuthRetrofitApiProvider = Provider<VoiceMemoryAuthApi>(
  (ref) => ref.watch(voiceMemoryRetrofitClientProvider).auth,
);

final voiceMemorySyncRetrofitApiProvider = Provider<VoiceMemorySyncApi>(
  (ref) => ref.watch(voiceMemoryRetrofitClientProvider).sync,
);

final voiceMemoryCaptureRetrofitApiProvider = Provider<VoiceMemoryCaptureApi>(
  (ref) => ref.watch(voiceMemoryRetrofitClientProvider).capture,
);

final voiceMemoryInsightsRetrofitApiProvider = Provider<VoiceMemoryInsightsApi>(
  (ref) => ref.watch(voiceMemoryRetrofitClientProvider).insights,
);