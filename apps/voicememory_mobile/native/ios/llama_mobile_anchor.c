#include "../llama_mobile.h"

// Keeps CocoaPods' framework target concrete. The native archive itself is
// force-loaded by the podspec so its C ABI is visible to DynamicLibrary.process.
int32_t archiveme_llama_mobile_link_anchor(void) {
    return llama_mobile_abi_version();
}
