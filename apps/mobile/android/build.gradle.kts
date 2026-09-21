allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Sherpa plugin modules are sibling Gradle projects (not children of :app), so
// their packaging excludes must be applied here. Strip only sherpa's bundled
// libonnxruntime.so; keep libsherpa-onnx-c-api.so / libsherpa-onnx-cxx-api.so.
// Maven onnxruntime-android:1.27.1 remains the runtime (see app/build.gradle.kts).
subprojects {
    if (name.startsWith("sherpa_onnx_android")) {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                packaging {
                    jniLibs {
                        excludes += "lib/**/libonnxruntime.so"
                    }
                }
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
