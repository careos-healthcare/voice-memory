cmake_minimum_required(VERSION 3.22)
project(archiveme_llama_mobile LANGUAGES C CXX)

set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/llama.cpp")
if(NOT EXISTS "${LLAMA_CPP_DIR}/include/llama.h")
  message(FATAL_ERROR
    "Pinned llama.cpp checkout missing. Run tool/fetch_llama_cpp.sh first.")
endif()

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_CCACHE OFF CACHE BOOL "" FORCE)

if(ANDROID)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  set(GGML_BLAS OFF CACHE BOOL "" FORCE)
  set(GGML_ACCELERATE OFF CACHE BOOL "" FORCE)
endif()

if(APPLE)
  set(GGML_METAL ON CACHE BOOL "" FORCE)
  set(GGML_METAL_EMBED_LIBRARY ON CACHE BOOL "" FORCE)
  set(GGML_BLAS ON CACHE BOOL "" FORCE)
  set(GGML_BLAS_VENDOR Apple CACHE STRING "" FORCE)
  set(GGML_ACCELERATE ON CACHE BOOL "" FORCE)
endif()

add_subdirectory("${LLAMA_CPP_DIR}" llama.cpp)

if(ANDROID)
  add_library(llama_mobile SHARED llama_mobile.cpp apex_native_guard.cpp)
else()
  add_library(llama_mobile_core STATIC llama_mobile.cpp apex_native_guard.cpp)
  set_target_properties(llama_mobile_core PROPERTIES
    OUTPUT_NAME llama_mobile_core)
endif()

set(LLAMA_MOBILE_TARGET llama_mobile_core)
if(ANDROID)
  set(LLAMA_MOBILE_TARGET llama_mobile)
endif()

target_include_directories(${LLAMA_MOBILE_TARGET}
  PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"
  PRIVATE "${LLAMA_CPP_DIR}/include")
target_compile_features(${LLAMA_MOBILE_TARGET} PRIVATE cxx_std_17)
target_compile_options(${LLAMA_MOBILE_TARGET} PRIVATE
  -fvisibility=hidden
  -fvisibility-inlines-hidden
  "$<$<CONFIG:Release>:-O3>"
  "$<$<CONFIG:Release>:-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.>"
  "$<$<CONFIG:Release>:-fdebug-prefix-map=${CMAKE_SOURCE_DIR}=.>")
target_compile_definitions(${LLAMA_MOBILE_TARGET} PRIVATE
  "$<$<CONFIG:Release>:NDEBUG>")
target_link_libraries(${LLAMA_MOBILE_TARGET} PRIVATE llama)

if(ANDROID)
  target_link_options(llama_mobile PRIVATE
    "-Wl,--exclude-libs,ALL"
    "-Wl,--gc-sections")
  target_link_libraries(llama_mobile PRIVATE log android)
endif()
