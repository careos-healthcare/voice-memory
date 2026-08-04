Pod::Spec.new do |spec|
  spec.name = 'LlamaMobile'
  spec.version = '1.0.0'
  spec.summary = 'ArchiveMe pinned llama.cpp C ABI runtime'
  spec.homepage = 'https://github.com/ggml-org/llama.cpp'
  spec.license = { :type => 'MIT' }
  spec.author = 'ArchiveMe'
  spec.source = { :path => '.' }
  spec.platform = :ios, '14.0'
  spec.source_files = 'llama_mobile_anchor.c', '../llama_mobile.h'
  spec.public_header_files = '../llama_mobile.h'
  spec.frameworks = 'Accelerate', 'Metal', 'MetalKit', 'Foundation'
  spec.libraries = 'c++'

  archive = '${PODS_TARGET_SRCROOT}/build/${PLATFORM_NAME}/libllama_mobile.a'
  spec.pod_target_xcconfig = {
    'IPHONEOS_DEPLOYMENT_TARGET' => '14.0',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO',
    'OTHER_LDFLAGS' => "$(inherited) -Wl,-force_load,#{archive}",
  }
  spec.script_phase = {
    :name => 'Build pinned llama.cpp runtime',
    :script => '"${PODS_TARGET_SRCROOT}/build_ios_slice.sh" "${PLATFORM_NAME}" "${CURRENT_ARCH}" "${NATIVE_ARCH_ACTUAL}" "${ARCHS}"',
    :execution_position => :before_compile,
    :input_files => [
      '${PODS_TARGET_SRCROOT}/../llama_mobile.cpp',
      '${PODS_TARGET_SRCROOT}/../llama_mobile.h',
      '${PODS_TARGET_SRCROOT}/../../third_party/llama.cpp.lock.json',
    ],
    :output_files => [archive],
  }
end
