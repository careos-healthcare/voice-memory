#ifndef ARCHIVEME_NEURAL_TRAINER_MOBILE_H
#define ARCHIVEME_NEURAL_TRAINER_MOBILE_H

#include <stdint.h>

#if defined(_WIN32)
#define NEURAL_TRAINER_EXPORT __declspec(dllexport)
#else
#define NEURAL_TRAINER_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define NEURAL_TRAINER_ABI_VERSION 1

typedef struct neural_trainer_job neural_trainer_job;

typedef enum neural_trainer_status {
  NEURAL_TRAINER_OK = 0,
  NEURAL_TRAINER_UNSUPPORTED = 1,
  NEURAL_TRAINER_INVALID_ARGUMENT = 2,
  NEURAL_TRAINER_FAILED = 3,
  NEURAL_TRAINER_CANCELLED = 4
} neural_trainer_status;

typedef struct neural_trainer_configuration {
  const char *base_model_path;
  const char *base_model_sha256;
  const char *dataset_jsonl_path;
  const char *output_directory;
  int32_t epochs;
  int32_t rank;
  float learning_rate;
} neural_trainer_configuration;

typedef struct neural_trainer_progress {
  int32_t epoch;
  int32_t total_epochs;
  int64_t tokens_processed;
  float loss;
  int32_t finished;
  const char *safetensors_path;
  const char *gguf_adapter_path;
  const char *error_message;
} neural_trainer_progress;

NEURAL_TRAINER_EXPORT int32_t neural_trainer_abi_version(void);
NEURAL_TRAINER_EXPORT const char *neural_trainer_backend_name(void);
NEURAL_TRAINER_EXPORT int32_t neural_trainer_is_available(void);
NEURAL_TRAINER_EXPORT neural_trainer_status neural_trainer_start(
    const neural_trainer_configuration *configuration,
    neural_trainer_job **out_job);
NEURAL_TRAINER_EXPORT neural_trainer_status neural_trainer_poll(
    neural_trainer_job *job,
    neural_trainer_progress *out_progress);
NEURAL_TRAINER_EXPORT neural_trainer_status neural_trainer_pause(
    neural_trainer_job *job);
NEURAL_TRAINER_EXPORT neural_trainer_status neural_trainer_resume(
    neural_trainer_job *job);
NEURAL_TRAINER_EXPORT neural_trainer_status neural_trainer_cancel(
    neural_trainer_job *job);
NEURAL_TRAINER_EXPORT void neural_trainer_dispose(neural_trainer_job *job);

#ifdef __cplusplus
}
#endif

#endif
