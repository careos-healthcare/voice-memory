#ifndef ARCHIVEME_WASM_SANDBOX_ENCLAVE_H
#define ARCHIVEME_WASM_SANDBOX_ENCLAVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ARCHIVEME_WASM_SANDBOX_ABI_VERSION 1

typedef struct archiveme_wasm_job archiveme_wasm_job;

typedef struct archiveme_wasm_limits {
  uint64_t maximum_fuel;
  uint64_t maximum_memory_bytes;
  uint64_t maximum_output_bytes;
} archiveme_wasm_limits;

typedef struct archiveme_wasm_job_status {
  int32_t finished;
  int32_t succeeded;
  uint64_t fuel_consumed;
  uint64_t peak_memory_bytes;
  const uint8_t* output_bytes;
  size_t output_length;
  const char* error_message;
} archiveme_wasm_job_status;

int32_t archiveme_wasm_abi_version(void);
int32_t archiveme_wasm_is_available(void);
const char* archiveme_wasm_backend_name(void);

/*
 * The runtime MUST instantiate without WASI and with no ambient imports.
 * module_bytes and input_bytes are copied before this call returns.
 */
int32_t archiveme_wasm_job_create(
    const uint8_t* module_bytes,
    size_t module_length,
    const char* entrypoint,
    const uint8_t* input_bytes,
    size_t input_length,
    const archiveme_wasm_limits* limits,
    archiveme_wasm_job** output_job);

int32_t archiveme_wasm_job_poll(
    archiveme_wasm_job* job,
    archiveme_wasm_job_status* output_status);
int32_t archiveme_wasm_job_cancel(archiveme_wasm_job* job);
void archiveme_wasm_job_dispose(archiveme_wasm_job* job);

#ifdef __cplusplus
}
#endif

#endif
