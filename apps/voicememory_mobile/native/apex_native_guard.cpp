#include "apex_native_guard.h"

#include <atomic>

namespace {
std::atomic<uint64_t> g_counts[APEX_NATIVE_RESOURCE_KIND_COUNT];
std::atomic<uint64_t> g_bytes[APEX_NATIVE_RESOURCE_KIND_COUNT];
std::atomic<uint64_t> g_invalid_releases{0};

bool valid(apex_native_resource_kind kind) {
    return kind >= 0 && kind < APEX_NATIVE_RESOURCE_KIND_COUNT;
}
}

uint32_t apex_native_guard_abi_version(void) {
    return 1;
}

void apex_native_guard_acquire(
    apex_native_resource_kind kind,
    uint64_t estimated_bytes) {
    if (!valid(kind)) {
        return;
    }
    g_counts[kind].fetch_add(1, std::memory_order_relaxed);
    g_bytes[kind].fetch_add(estimated_bytes, std::memory_order_relaxed);
}

void apex_native_guard_release(
    apex_native_resource_kind kind,
    uint64_t estimated_bytes) {
    if (!valid(kind)) {
        return;
    }
    uint64_t current_count = g_counts[kind].load(std::memory_order_relaxed);
    while (current_count > 0 &&
           !g_counts[kind].compare_exchange_weak(
               current_count, current_count - 1, std::memory_order_relaxed)) {}
    if (current_count == 0) {
        g_invalid_releases.fetch_add(1, std::memory_order_relaxed);
        return;
    }
    uint64_t current_bytes = g_bytes[kind].load(std::memory_order_relaxed);
    while (!g_bytes[kind].compare_exchange_weak(
        current_bytes,
        estimated_bytes > current_bytes ? 0 : current_bytes - estimated_bytes,
        std::memory_order_relaxed)) {}
}

uint64_t apex_native_guard_active_count(apex_native_resource_kind kind) {
    return valid(kind) ? g_counts[kind].load(std::memory_order_relaxed) : 0;
}

uint64_t apex_native_guard_active_bytes(apex_native_resource_kind kind) {
    return valid(kind) ? g_bytes[kind].load(std::memory_order_relaxed) : 0;
}

uint64_t apex_native_guard_invalid_release_count(void) {
    return g_invalid_releases.load(std::memory_order_relaxed);
}
