# Voice Memory API Contract

OpenAPI 3.0 spec for the Next.js handlers under `apps/api/app/api/**/route.ts`.

## Source of truth

- **Spec:** `openapi.yaml`
- **Mobile typed paths:** `apps/mobile/lib/core/network/voice_memory_api_routes.dart`
- **Mobile Retrofit clients:** `apps/mobile/lib/api/retrofit/` (generated `*.g.dart` via `build_runner`)

## Regenerate Retrofit clients

After changing `openapi.yaml`, update the matching `@RestApi` interfaces in
`apps/mobile/lib/api/retrofit/` if paths or methods changed, then:

```bash
cd apps/mobile
dart run build_runner build --build-filter="lib/api/retrofit/*.dart"
```

## Validate path parity

```bash
cd apps/mobile
dart run tool/validate_api_contract.dart
dart run tool/run_api_dto_self_test.dart
```

## Typed DTOs (auth + sync)

High-traffic Retrofit responses use `@JsonSerializable` models in
`apps/mobile/lib/api/models/`:

- **Auth:** `AuthVerifyResponseDto`, `AuthSessionResponseDto` → `UserSession`
- **Sync:** `SyncPushResponseDto`, `SyncPullResponseDto`, `SyncChangesResponseDto`,
  `SyncManifestResponseDto`, `SyncPushRequestDto`

Regenerate after editing DTOs:

```bash
cd apps/mobile
dart run build_runner build --build-filter="lib/api/models/*.dart" --build-filter="lib/api/retrofit/*.dart"
```

## Mobile base URL

Inject at runtime via Riverpod (`voiceMemoryApiBaseUrlProvider`) — never hardcode
in generated clients. Run:

```bash
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000
```
