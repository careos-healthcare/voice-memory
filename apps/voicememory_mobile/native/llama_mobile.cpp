#include "llama_mobile.h"
#include "apex_native_guard.h"

#include "llama.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <unordered_set>
#include <vector>

struct llama_mobile_session {
    llama_model * model = nullptr;
    llama_context * context = nullptr;
    llama_adapter_lora * adapter = nullptr;
    const llama_vocab * vocab = nullptr;
    uint32_t n_ctx = 0;
    std::atomic<bool> cancelled{false};
    std::atomic<int64_t> deadline_ms{0};
    std::string last_error;
    std::mutex mutex;
};

namespace {

constexpr int32_t kMinContext = 256;
constexpr int32_t kMaxContext = 8192;
constexpr int32_t kMaxTokens = 1024;
constexpr int32_t kMaxThreads = 8;
constexpr int32_t kMaxTimeoutMs = 300000;

std::once_flag g_backend_once;
std::mutex g_handle_mutex;
std::unordered_set<const llama_mobile_session *> g_sessions;
std::unordered_set<const char *> g_outputs;

bool is_known_session(const llama_mobile_session * session) {
    if (session == nullptr) {
        return false;
    }
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    return g_sessions.find(session) != g_sessions.end();
}

void register_session(const llama_mobile_session * session) {
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    g_sessions.insert(session);
}

bool unregister_session(const llama_mobile_session * session) {
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    return g_sessions.erase(session) == 1;
}

void register_output(const char * output) {
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    g_outputs.insert(output);
}

bool unregister_output(const char * output) {
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    return g_outputs.erase(output) == 1;
}

int64_t monotonic_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

void silent_log_callback(enum ggml_log_level, const char *, void *) {}

void initialize_backend() {
    llama_log_set(silent_log_callback, nullptr);
    llama_backend_init();
}

bool should_abort(void * data) {
    auto * session = static_cast<llama_mobile_session *>(data);
    if (session->cancelled.load(std::memory_order_relaxed)) {
        return true;
    }
    const int64_t deadline = session->deadline_ms.load(std::memory_order_relaxed);
    return deadline > 0 && monotonic_ms() >= deadline;
}

llama_mobile_status fail(
    llama_mobile_session * session,
    llama_mobile_status status,
    const char * message) {
    if (session != nullptr) {
        session->last_error = message;
    }
    return status;
}

llama_mobile_status abort_status(llama_mobile_session * session) {
    if (session->cancelled.load(std::memory_order_relaxed)) {
        return fail(session, LLAMA_MOBILE_CANCELLED, "inference cancelled");
    }
    return fail(session, LLAMA_MOBILE_TIMED_OUT, "inference timed out");
}

llama_mobile_status decode(
    llama_mobile_session * session,
    llama_token * tokens,
    int32_t count) {
    const int32_t batch_limit =
        std::min<int32_t>(512, static_cast<int32_t>(session->n_ctx));
    for (int32_t offset = 0; offset < count; offset += batch_limit) {
        if (should_abort(session)) {
            return abort_status(session);
        }
        const int32_t chunk = std::min(batch_limit, count - offset);
        llama_batch batch = llama_batch_get_one(tokens + offset, chunk);
        const int32_t result = llama_decode(session->context, batch);
        if (result == 2 || should_abort(session)) {
            return abort_status(session);
        }
        if (result != 0) {
            return fail(session, LLAMA_MOBILE_DECODE_FAILED, "llama_decode failed");
        }
    }
    return LLAMA_MOBILE_OK;
}

llama_mobile_status append_piece(
    llama_mobile_session * session,
    llama_token token,
    std::string * output) {
    char stack_buffer[256];
    int32_t size = llama_token_to_piece(
        session->vocab, token, stack_buffer, sizeof(stack_buffer), 0, false);
    if (size >= 0) {
        output->append(stack_buffer, static_cast<size_t>(size));
        return LLAMA_MOBILE_OK;
    }

    std::vector<char> buffer(static_cast<size_t>(-size));
    size = llama_token_to_piece(
        session->vocab, token, buffer.data(), buffer.size(), 0, false);
    if (size < 0) {
        return fail(
            session, LLAMA_MOBILE_INTERNAL_ERROR, "token conversion failed");
    }
    output->append(buffer.data(), static_cast<size_t>(size));
    return LLAMA_MOBILE_OK;
}

}  // namespace

extern "C" {

llama_mobile_status llama_mobile_session_create(
    const char * model_path,
    int32_t n_ctx,
    int32_t n_threads,
    int32_t n_gpu_layers,
    llama_mobile_session ** out_session) {
    if (out_session == nullptr) {
        return LLAMA_MOBILE_INVALID_ARGUMENT;
    }
    *out_session = nullptr;
    if (model_path == nullptr || model_path[0] == '\0' ||
        n_ctx < kMinContext || n_ctx > kMaxContext ||
        n_threads < 1 || n_threads > kMaxThreads ||
        n_gpu_layers < -1 || n_gpu_layers > 256) {
        return LLAMA_MOBILE_INVALID_ARGUMENT;
    }

    try {
        std::call_once(g_backend_once, initialize_backend);
        auto * session = new (std::nothrow) llama_mobile_session();
        if (session == nullptr) {
            return LLAMA_MOBILE_OUT_OF_MEMORY;
        }

        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = n_gpu_layers;
        session->model = llama_model_load_from_file(model_path, model_params);
        if (session->model == nullptr) {
            delete session;
            return LLAMA_MOBILE_MODEL_LOAD_FAILED;
        }
        if (llama_model_has_encoder(session->model)) {
            llama_model_free(session->model);
            delete session;
            return LLAMA_MOBILE_CONTEXT_CREATE_FAILED;
        }

        llama_context_params context_params = llama_context_default_params();
        context_params.n_ctx = static_cast<uint32_t>(n_ctx);
        context_params.n_batch = std::min<int32_t>(n_ctx, 512);
        context_params.n_ubatch = context_params.n_batch;
        context_params.n_threads = n_threads;
        context_params.n_threads_batch = n_threads;
        context_params.no_perf = true;
        context_params.abort_callback = should_abort;
        context_params.abort_callback_data = session;

        session->context = llama_init_from_model(session->model, context_params);
        if (session->context == nullptr) {
            llama_model_free(session->model);
            delete session;
            return LLAMA_MOBILE_CONTEXT_CREATE_FAILED;
        }
        session->vocab = llama_model_get_vocab(session->model);
        session->n_ctx = static_cast<uint32_t>(n_ctx);
        register_session(session);
        *out_session = session;
        apex_native_guard_acquire(APEX_NATIVE_LLAMA_SESSION, 0);
        return LLAMA_MOBILE_OK;
    } catch (...) {
        return LLAMA_MOBILE_INTERNAL_ERROR;
    }
}

llama_mobile_status llama_mobile_complete(
    llama_mobile_session * session,
    const char * prompt,
    int32_t max_tokens,
    int32_t timeout_ms,
    char ** out_text) {
    if (!is_known_session(session) || prompt == nullptr || out_text == nullptr ||
        max_tokens < 1 || max_tokens > kMaxTokens ||
        timeout_ms < 1 || timeout_ms > kMaxTimeoutMs) {
        return LLAMA_MOBILE_INVALID_ARGUMENT;
    }
    *out_text = nullptr;
    std::lock_guard<std::mutex> lock(session->mutex);

    try {
        session->last_error.clear();
        session->cancelled.store(false, std::memory_order_relaxed);
        session->deadline_ms.store(
            monotonic_ms() + timeout_ms, std::memory_order_relaxed);
        llama_memory_clear(llama_get_memory(session->context), true);

        const size_t prompt_size = std::strlen(prompt);
        if (prompt_size > static_cast<size_t>(INT32_MAX)) {
            return fail(
                session, LLAMA_MOBILE_INVALID_ARGUMENT, "prompt is too large");
        }
        const int32_t required = llama_tokenize(
            session->vocab,
            prompt,
            static_cast<int32_t>(prompt_size),
            nullptr,
            0,
            true,
            true);
        if (required >= 0) {
            return fail(
                session, LLAMA_MOBILE_TOKENIZE_FAILED, "empty tokenization");
        }
        const int32_t prompt_tokens_count = -required;
        if (prompt_tokens_count + max_tokens > static_cast<int32_t>(session->n_ctx)) {
            return fail(
                session,
                LLAMA_MOBILE_CONTEXT_LIMIT,
                "prompt and output exceed context limit");
        }

        std::vector<llama_token> prompt_tokens(prompt_tokens_count);
        const int32_t tokenized = llama_tokenize(
            session->vocab,
            prompt,
            static_cast<int32_t>(prompt_size),
            prompt_tokens.data(),
            prompt_tokens_count,
            true,
            true);
        if (tokenized != prompt_tokens_count) {
            return fail(
                session, LLAMA_MOBILE_TOKENIZE_FAILED, "tokenization failed");
        }

        llama_mobile_status status =
            decode(session, prompt_tokens.data(), prompt_tokens_count);
        if (status != LLAMA_MOBILE_OK) {
            return status;
        }

        llama_sampler_chain_params sampler_params =
            llama_sampler_chain_default_params();
        sampler_params.no_perf = true;
        std::unique_ptr<llama_sampler, decltype(&llama_sampler_free)> sampler(
            llama_sampler_chain_init(sampler_params), llama_sampler_free);
        if (sampler == nullptr) {
            return fail(
                session, LLAMA_MOBILE_OUT_OF_MEMORY, "sampler allocation failed");
        }
        llama_sampler_chain_add(sampler.get(), llama_sampler_init_greedy());

        std::string output;
        output.reserve(static_cast<size_t>(max_tokens) * 8);
        for (int32_t index = 0; index < max_tokens; ++index) {
            if (should_abort(session)) {
                return abort_status(session);
            }
            llama_token token =
                llama_sampler_sample(sampler.get(), session->context, -1);
            if (llama_vocab_is_eog(session->vocab, token)) {
                break;
            }
            status = append_piece(session, token, &output);
            if (status != LLAMA_MOBILE_OK) {
                return status;
            }
            status = decode(session, &token, 1);
            if (status != LLAMA_MOBILE_OK) {
                return status;
            }
        }

        const size_t allocation_size = output.size() + 1;
        void * allocation = std::malloc(sizeof(size_t) + allocation_size);
        if (allocation == nullptr) {
            return fail(
                session, LLAMA_MOBILE_OUT_OF_MEMORY, "output allocation failed");
        }
        *static_cast<size_t *>(allocation) = allocation_size;
        char * result =
            reinterpret_cast<char *>(allocation) + sizeof(size_t);
        std::memcpy(result, output.data(), output.size());
        result[output.size()] = '\0';
        register_output(result);
        *out_text = result;
        apex_native_guard_acquire(
            APEX_NATIVE_LLAMA_OUTPUT, allocation_size);
        session->deadline_ms.store(0, std::memory_order_relaxed);
        return LLAMA_MOBILE_OK;
    } catch (const std::bad_alloc &) {
        return fail(
            session, LLAMA_MOBILE_OUT_OF_MEMORY, "native allocation failed");
    } catch (...) {
        return fail(
            session, LLAMA_MOBILE_INTERNAL_ERROR, "unexpected native failure");
    }
}

void llama_mobile_cancel(llama_mobile_session * session) {
    if (is_known_session(session)) {
        session->cancelled.store(true, std::memory_order_relaxed);
    }
}

llama_mobile_status llama_mobile_adapter_load(
    llama_mobile_session * session,
    const char * adapter_path,
    float scale) {
    if (!is_known_session(session) || adapter_path == nullptr ||
        adapter_path[0] == '\0' || !std::isfinite(scale) ||
        scale < 0.0f || scale > 4.0f) {
        return LLAMA_MOBILE_INVALID_ARGUMENT;
    }
    std::lock_guard<std::mutex> lock(session->mutex);
    llama_adapter_lora * next =
        llama_adapter_lora_init(session->model, adapter_path);
    if (next == nullptr) {
        return fail(
            session, LLAMA_MOBILE_MODEL_LOAD_FAILED, "LoRA adapter load failed");
    }
    llama_adapter_lora * adapters[] = {next};
    float scales[] = {scale};
    if (llama_set_adapters_lora(session->context, adapters, 1, scales) != 0) {
        llama_adapter_lora_free(next);
        return fail(
            session, LLAMA_MOBILE_INTERNAL_ERROR, "LoRA adapter apply failed");
    }
    if (session->adapter != nullptr) {
        llama_adapter_lora_free(session->adapter);
    }
    session->adapter = next;
    session->last_error.clear();
    return LLAMA_MOBILE_OK;
}

llama_mobile_status llama_mobile_adapter_unload(llama_mobile_session * session) {
    if (!is_known_session(session)) {
        return LLAMA_MOBILE_INVALID_ARGUMENT;
    }
    std::lock_guard<std::mutex> lock(session->mutex);
    if (llama_set_adapters_lora(session->context, nullptr, 0, nullptr) != 0) {
        return fail(
            session, LLAMA_MOBILE_INTERNAL_ERROR, "LoRA adapter unload failed");
    }
    if (session->adapter != nullptr) {
        llama_adapter_lora_free(session->adapter);
        session->adapter = nullptr;
    }
    session->last_error.clear();
    return LLAMA_MOBILE_OK;
}

const char * llama_mobile_last_error(const llama_mobile_session * session) {
    return !is_known_session(session) ? "invalid session" : session->last_error.c_str();
}

void llama_mobile_output_free(char * output) {
    if (unregister_output(output)) {
        void * allocation = output - sizeof(size_t);
        const size_t allocation_size = *static_cast<size_t *>(allocation);
        apex_native_guard_release(APEX_NATIVE_LLAMA_OUTPUT, allocation_size);
        std::free(allocation);
    }
}

void llama_mobile_session_dispose(llama_mobile_session * session) {
    if (!unregister_session(session)) {
        return;
    }
    session->cancelled.store(true, std::memory_order_relaxed);
    std::lock_guard<std::mutex> lock(session->mutex);
    if (session->adapter != nullptr) {
        llama_adapter_lora_free(session->adapter);
        session->adapter = nullptr;
    }
    if (session->context != nullptr) {
        llama_free(session->context);
    }
    if (session->model != nullptr) {
        llama_model_free(session->model);
    }
    delete session;
    apex_native_guard_release(APEX_NATIVE_LLAMA_SESSION, 0);
}

int32_t llama_mobile_abi_version(void) {
    return 2;
}

}  // extern "C"
