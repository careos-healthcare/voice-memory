# Dependency diet

Proposal only. Nothing in this document has been removed. Native binary size
before and after a removal is not measured: `apps/mobile` has no checked-in
IPA, and this pass does not build or strip one.

Production call sites are under `apps/mobile/lib`. Tests and `retired_sprawl`
are excluded.

## On-device ML

| Package | Role today | Production call sites |
| --- | --- | --- |
| `flutter_gemma` | Gemma engine host | `lib/services/ai/ai_service.dart` (`FlutterGemma.initialize`, model install, `getActiveModel`) |
| `flutter_gemma_litertlm` | LiteRT-LM inference engine registered by that host | `lib/services/ai/ai_service.dart` (`LiteRtLmEngine`) |
| `flutter_gemma_speech` | Moonshine STT | `lib/services/ai/ai_service.dart` (`LiteRtSttBackend`, `installStt`, `getActiveStt`, `transcribe`) |
| `llama_cpp_dart` | GGUF LLM worker for capture and structuring | `lib/workers/local_llm/local_llm_worker_service.dart`, `lib/services/local_llm/local_llm_config.dart`, `lib/services/audio_structuring/audio_structuring_prompt.dart`. `LocalLlmBootstrap` / `LlamaCppDartBackend` call the worker. |
| `flutter_onnxruntime` | Embeddings and voice-activity detection | `lib/features/search/onnx_reflection_embedding_inference.dart` (wired from `storage_providers.dart`, `offline_reflection_vector_search_service.dart`, `embedding_index_worker_service.dart`). `lib/features/capture/vad/onnx_vad_inference.dart` (wired from `vad_streaming_service.dart`). |
| `sherpa_onnx` | Offline TTS, not STT | `lib/services/offline_tts/sherpa_onnx_tts_backend.dart`, constructed by `lib/services/offline_tts/offline_tts_service.dart`. |

`ios/Podfile.lock` has no ObjectBox pod. `Package.resolved` does pull
`onnxruntime-swift-package-manager` for `flutter_onnxruntime`.

## Database

| Package | Role today | Production call sites |
| --- | --- | --- |
| `sqflite` | Dart database API and plaintext open | Journal, sync, migration, and search stores under `lib/storage/sqlite/`, `lib/sync/`, `lib/database/app_database.dart`, `lib/database/executor/wrapped_sqflite_executor.dart`. |
| `sqflite_sqlcipher` | Keyed open on iOS and Android | `lib/storage/sqlite/sqlite_database_initializer.dart`, `lib/storage/sqlite/isolate_safe_sqlite_database_initializer.dart`. `Podfile.lock` pins SQLCipher 4.10.0. |
| `drift` | Typed tables and DAOs on the same sqflite connection | `lib/database/**`, `lib/sync/sync_outbox_store.dart`, `lib/features/insights/rag/local_reflection_rag_drift_queries.dart`, `lib/features/insights/trend_analysis/trend_analysis_drift_queries.dart`. |
| `sqlite3` | SQLCipher build (`hooks.user_defines.sqlite3.source: sqlcipher`) and the sqlite-vector extension | `lib/storage/sqlite/sqlite_vector_support.dart`, `lib/src/native/sqlite_vector_extension.dart`. |
| ObjectBox | Not present | No Dart import and no pod. |

## Proposed keep-set

One of each. Removal waits for approval.

| Slot | Keep | Leave for a later removal |
| --- | --- | --- |
| LLM | `llama_cpp_dart` | `flutter_gemma` and `flutter_gemma_litertlm`. Capture already loads GGUF through `LocalLlmBootstrap`. `AIService` is a second generative stack. |
| STT | `flutter_gemma_speech` | No other production STT exists. `sherpa_onnx` is TTS. Speech may keep a `flutter_gemma` host even after the LiteRT-LM engine is dropped; that split needs its own check before the Gemma pods go. |
| Embeddings | `flutter_onnxruntime` | `sherpa_onnx` ships a second ONNX runtime for TTS only. |
| Database | SQLCipher through `sqflite_sqlcipher`, with Drift on that connection and the `sqlite3` package for the cipher build plus sqlite-vector | ObjectBox (already absent). A second plaintext engine is not a separate product database; device opens that ask for a key stay on SQLCipher. |

### Size

| Build | IPA |
| --- | --- |
| Current tree | No IPA on disk. Not measured. |
| After the keep-set above | Not measured. This document does not remove packages, so there is no after artifact. |

Expected direction, still unmeasured: dropping LiteRT-LM and the sherpa ONNX TTS binary is the large native cut. `flutter_gemma_speech` and `flutter_onnxruntime` stay, so their native libraries stay in the IPA. SQLCipher stays.

## HTTP clients

`http` is the app transport. `dio` plus `retrofit` is a second client for the same API, plus two direct Dio callers.

`http` production call sites:

- `lib/core/network/http_transport.dart` (constructed in `lib/services/app_services.dart` and `lib/core/di/network_providers.dart`)
- `lib/services/api_service.dart`
- `lib/services/backlog_import_service.dart`
- `lib/data/network/http_sync_api_client.dart`, `http_user_relationship_api_client.dart`, `http_push_api_client.dart`, `http_billing_api_client.dart`, `http_account_api_client.dart`, `http_auth_api_client.dart`, `http_caregiver_consent_api_client.dart`, `auth_api_client.dart`
- `lib/api/api_errors.dart`, `lib/core/network/api_failure_mapper.dart`, `lib/core/network/multipart_file_part.dart`, `lib/security/api_response_safety.dart`

`dio` / `retrofit` production call sites:

- Generated surface: `lib/api/retrofit/voice_memory_*_api.dart`, assembled by `lib/api/retrofit/voice_memory_retrofit_client.dart`
- `lib/core/di/retrofit_providers.dart`, `lib/api/dio/voice_memory_dio_factory.dart`, `lib/api/dio/session_cookie_capture.dart`, `lib/api/dio/retrofit_api_executor.dart`
- `lib/core/network/voice_memory_api_client_bundle.dart` builds that client when Dio is configured
- Direct Dio, outside Retrofit: `lib/services/local_llm/model_download_service.dart`, `lib/features/caregiver_grant/caregiver_redemption_service.dart`

Keep `http`. It is the client `AppServices` actually constructs for account, sync, billing, and consent. Fold the Retrofit bundle and the two direct Dio callers onto `HttpTransport` in a later change. Do not delete `dio` or `retrofit` until those three call sites compile against `http`.
