# llama.cpp FFI runtime

The exact upstream commit and archive SHA-256 are recorded in
`third_party/llama.cpp.lock.json`. Run `tool/fetch_llama_cpp.sh` once to fetch
and verify the ignored source checkout. Android and iOS release builds never
fetch from the network and fail with a clear CMake error if that checkout is
missing. No model weights are bundled.

`native/llama_mobile.h` is the Dart-facing ABI. Completion is greedy, bounded,
deadline/cancellation aware, and does not log prompts or output.

Android builds arm64-v8a and x86_64 with `native/CMakeLists.txt`. iOS remains at
target 13; its local pod force-loads a static archive with Accelerate and Metal,
making symbols visible to `DynamicLibrary.process()`.

`LlamaInferenceSession` owns one model/context on a long-lived worker isolate.
Calls are serialized, bounded by native and Dart deadlines, and parsed as one
strict semantic JSON object. User text and generated output are never logged.

```sh
tool/fetch_llama_cpp.sh
(cd ios && pod install)
native/ios/build_ios_xcframework.sh
flutter test test/core/llm/native/llama_inference_session_test.dart
```

The opt-in smoke test needs an external tiny GGUF:

```sh
ARCHIVEME_RUN_LLAMA_FFI=true \
ARCHIVEME_LLAMA_GGUF_PATH=/absolute/tiny.gguf \
flutter test test/core/llm/native/llama_native_abi_smoke_test.dart
```

For a host run, also set `ARCHIVEME_LLAMA_LIBRARY`. Android/iOS resolve their
configured library automatically.
