#ifndef ARCHIVEME_SPATIAL_NEXUS_MOBILE_H
#define ARCHIVEME_SPATIAL_NEXUS_MOBILE_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define SPATIAL_NEXUS_EXPORT __declspec(dllexport)
#else
#define SPATIAL_NEXUS_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define SPATIAL_NEXUS_ABI_VERSION 1

typedef enum spatial_nexus_capability {
  SPATIAL_NEXUS_CAPABILITY_METAL = 1 << 0,
  SPATIAL_NEXUS_CAPABILITY_VULKAN = 1 << 1,
  SPATIAL_NEXUS_CAPABILITY_HRTF = 1 << 2,
  SPATIAL_NEXUS_CAPABILITY_VISION_OS = 1 << 3,
  SPATIAL_NEXUS_CAPABILITY_OPENXR = 1 << 4
} spatial_nexus_capability;

typedef enum spatial_nexus_status {
  SPATIAL_NEXUS_OK = 0,
  SPATIAL_NEXUS_UNAVAILABLE = 1,
  SPATIAL_NEXUS_INVALID_ARGUMENT = 2,
  SPATIAL_NEXUS_POLICY_REJECTED = 3,
  SPATIAL_NEXUS_INTERNAL_ERROR = 4
} spatial_nexus_status;

typedef struct spatial_nexus_session spatial_nexus_session;

SPATIAL_NEXUS_EXPORT int32_t spatial_nexus_abi_version(void);
SPATIAL_NEXUS_EXPORT uint32_t spatial_nexus_capabilities(void);

/*
 * Native packages must return only capabilities backed by compiled platform
 * binaries. The Dart runtime fails closed when this library is absent.
 */
SPATIAL_NEXUS_EXPORT spatial_nexus_status spatial_nexus_session_create(
    uint32_t requested_capabilities,
    uint32_t max_nodes,
    spatial_nexus_session **out_session);

SPATIAL_NEXUS_EXPORT spatial_nexus_status spatial_nexus_scene_update(
    spatial_nexus_session *session,
    const uint8_t *scene_bytes,
    size_t scene_length);

SPATIAL_NEXUS_EXPORT spatial_nexus_status spatial_nexus_listener_update(
    spatial_nexus_session *session,
    float x,
    float y,
    float z,
    float forward_x,
    float forward_y,
    float forward_z);

SPATIAL_NEXUS_EXPORT void spatial_nexus_session_dispose(
    spatial_nexus_session *session);

#ifdef __cplusplus
}
#endif

#endif
