#ifndef ARCHIVEME_HIVEMIND_TRANSPORT_MOBILE_H
#define ARCHIVEME_HIVEMIND_TRANSPORT_MOBILE_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define HIVEMIND_TRANSPORT_EXPORT __declspec(dllexport)
#else
#define HIVEMIND_TRANSPORT_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define HIVEMIND_TRANSPORT_ABI_VERSION 1

typedef enum hivemind_transport_capability {
  HIVEMIND_TRANSPORT_CAPABILITY_WEBRTC_LOCAL_ONLY = 1 << 0,
  HIVEMIND_TRANSPORT_CAPABILITY_BLE_BEACON = 1 << 1,
  HIVEMIND_TRANSPORT_CAPABILITY_NOISE_XX = 1 << 2
} hivemind_transport_capability;

typedef enum hivemind_transport_status {
  HIVEMIND_TRANSPORT_OK = 0,
  HIVEMIND_TRANSPORT_UNAVAILABLE = 1,
  HIVEMIND_TRANSPORT_INVALID_ARGUMENT = 2,
  HIVEMIND_TRANSPORT_AUTHENTICATION_FAILED = 3,
  HIVEMIND_TRANSPORT_POLICY_REJECTED = 4,
  HIVEMIND_TRANSPORT_INTERNAL_ERROR = 5
} hivemind_transport_status;

typedef struct hivemind_transport_session hivemind_transport_session;

/*
 * Native packages must return only capabilities backed by platform binaries.
 * The Dart layer treats a missing library or a zero capability mask as
 * unavailable and never substitutes an Internet relay.
 */
HIVEMIND_TRANSPORT_EXPORT int32_t hivemind_transport_abi_version(void);
HIVEMIND_TRANSPORT_EXPORT uint32_t hivemind_transport_capabilities(void);

/*
 * Creates a local-only WebRTC data channel with BLE discovery and Noise XX
 * authentication where supported. ICE server and relay candidates are
 * intentionally absent from this ABI.
 */
HIVEMIND_TRANSPORT_EXPORT hivemind_transport_status
hivemind_transport_session_open(
    const uint8_t *trusted_ed25519_public_key,
    size_t trusted_ed25519_public_key_length,
    const uint8_t *local_identity_handle,
    size_t local_identity_handle_length,
    hivemind_transport_session **out_session);

HIVEMIND_TRANSPORT_EXPORT hivemind_transport_status
hivemind_transport_session_send(
    hivemind_transport_session *session,
    const uint8_t *cleartext,
    size_t cleartext_length);

HIVEMIND_TRANSPORT_EXPORT void hivemind_transport_session_close(
    hivemind_transport_session *session);

#ifdef __cplusplus
}
#endif

#endif
