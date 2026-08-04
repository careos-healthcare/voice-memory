#ifndef ARCHIVEME_LLAMA_MOBILE_H
#define ARCHIVEME_LLAMA_MOBILE_H

#include <stdint.h>

#if defined(_WIN32)
#define LLAMA_MOBILE_API __declspec(dllexport)
#else
#define LLAMA_MOBILE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct llama_mobile_session llama_mobile_session;

typedef enum llama_mobile_status {
    LLAMA_MOBILE_OK = 0,
    LLAMA_MOBILE_INVALID_ARGUMENT = 1,
    LLAMA_MOBILE_MODEL_LOAD_FAILED = 2,
    LLAMA_MOBILE_CONTEXT_CREATE_FAILED = 3,
    LLAMA_MOBILE_CONTEXT_LIMIT = 4,
    LLAMA_MOBILE_TOKENIZE_FAILED = 5,
    LLAMA_MOBILE_DECODE_FAILED = 6,
    LLAMA_MOBILE_CANCELLED = 7,
    LLAMA_MOBILE_TIMED_OUT = 8,
    LLAMA_MOBILE_OUT_OF_MEMORY = 9,
    LLAMA_MOBILE_INTERNAL_ERROR = 10
} llama_mobile_status;

// Creates a long-lived model/context pair from a local GGUF file.
// Bounds: n_ctx [256, 8192], n_threads [1, 8], n_gpu_layers [-1, 256].
LLAMA_MOBILE_API llama_mobile_status llama_mobile_session_create(
    const char * model_path,
    int32_t n_ctx,
    int32_t n_threads,
    int32_t n_gpu_layers,
    llama_mobile_session ** out_session);

// Greedy decoding is deterministic for a fixed model/build/prompt.
// Bounds: max_tokens [1, 1024], timeout_ms [1, 300000].
// The returned UTF-8 string must be released with llama_mobile_output_free.
LLAMA_MOBILE_API llama_mobile_status llama_mobile_complete(
    llama_mobile_session * session,
    const char * prompt,
    int32_t max_tokens,
    int32_t timeout_ms,
    char ** out_text);

LLAMA_MOBILE_API void llama_mobile_cancel(llama_mobile_session * session);
// Loads and applies one GGUF LoRA adapter. Calling this again atomically
// replaces the active adapter. Scale must be finite and in [0, 4].
LLAMA_MOBILE_API llama_mobile_status llama_mobile_adapter_load(
    llama_mobile_session * session,
    const char * adapter_path,
    float scale);
LLAMA_MOBILE_API llama_mobile_status llama_mobile_adapter_unload(
    llama_mobile_session * session);
LLAMA_MOBILE_API const char * llama_mobile_last_error(
    const llama_mobile_session * session);
LLAMA_MOBILE_API void llama_mobile_output_free(char * output);
LLAMA_MOBILE_API void llama_mobile_session_dispose(
    llama_mobile_session * session);
LLAMA_MOBILE_API int32_t llama_mobile_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif
