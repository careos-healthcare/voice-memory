#ifndef ARCHIVEME_APEX_NATIVE_GUARD_H
#define ARCHIVEME_APEX_NATIVE_GUARD_H

#include <stdint.h>

#if defined(_WIN32)
#define APEX_NATIVE_API __declspec(dllexport)
#else
#define APEX_NATIVE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum apex_native_resource_kind {
    APEX_NATIVE_LLAMA_SESSION = 0,
    APEX_NATIVE_LLAMA_OUTPUT = 1,
    APEX_NATIVE_RESOURCE_KIND_COUNT = 2
} apex_native_resource_kind;

APEX_NATIVE_API uint32_t apex_native_guard_abi_version(void);
APEX_NATIVE_API void apex_native_guard_acquire(
    apex_native_resource_kind kind,
    uint64_t estimated_bytes);
APEX_NATIVE_API void apex_native_guard_release(
    apex_native_resource_kind kind,
    uint64_t estimated_bytes);
APEX_NATIVE_API uint64_t apex_native_guard_active_count(
    apex_native_resource_kind kind);
APEX_NATIVE_API uint64_t apex_native_guard_active_bytes(
    apex_native_resource_kind kind);
APEX_NATIVE_API uint64_t apex_native_guard_invalid_release_count(void);

#ifdef __cplusplus
}
#endif

#endif
