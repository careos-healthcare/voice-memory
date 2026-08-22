import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing for Play Store uploads.
 *
 * Credentials come from ONE of:
 * 1. `android/key.properties` (gitignored — see key.properties.example), or
 * 2. Environment variables:
 *    - ARCHIVEME_ANDROID_KEYSTORE_FILE
 *    - ARCHIVEME_ANDROID_KEYSTORE_PASSWORD
 *    - ARCHIVEME_ANDROID_KEY_PASSWORD
 *    - ARCHIVEME_ANDROID_KEY_ALIAS
 *
 * Release and release-like tasks fail fast when credentials are absent.
 * They must never fall back to the debug keystore.
 */
data class ReleaseSigningCredentials(
    val storeFile: File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

fun loadReleaseSigningCredentials(androidRoot: File): ReleaseSigningCredentials? {
    val propertiesFile = androidRoot.resolve("key.properties")
    if (propertiesFile.isFile) {
        val props = Properties()
        FileInputStream(propertiesFile).use { props.load(it) }
        val storeFilePath = props.getProperty("storeFile")?.trim().orEmpty()
        val storePassword = props.getProperty("storePassword")?.trim().orEmpty()
        val keyAlias = props.getProperty("keyAlias")?.trim().orEmpty()
        val keyPassword = props.getProperty("keyPassword")?.trim().orEmpty()
        if (storeFilePath.isEmpty() || storePassword.isEmpty() || keyAlias.isEmpty() || keyPassword.isEmpty()) {
            throw GradleException(
                "android/key.properties exists but is incomplete. " +
                    "All of storeFile, storePassword, keyAlias and keyPassword are required. " +
                    "See android/key.properties.example and docs/ANDROID_RELEASE_CHECKLIST.md.",
            )
        }
        val storeFile = androidRoot.resolve(storeFilePath)
        if (!storeFile.isFile) {
            throw GradleException(
                "android/key.properties storeFile does not exist: ${storeFile.absolutePath}",
            )
        }
        return ReleaseSigningCredentials(
            storeFile = storeFile,
            storePassword = storePassword,
            keyAlias = keyAlias,
            keyPassword = keyPassword,
        )
    }

    val envStoreFile = System.getenv("ARCHIVEME_ANDROID_KEYSTORE_FILE")?.trim().orEmpty()
    if (envStoreFile.isEmpty()) {
        return null
    }
    val envStorePassword = System.getenv("ARCHIVEME_ANDROID_KEYSTORE_PASSWORD")?.trim().orEmpty()
    val envKeyAlias = System.getenv("ARCHIVEME_ANDROID_KEY_ALIAS")?.trim().orEmpty()
    val envKeyPassword = System.getenv("ARCHIVEME_ANDROID_KEY_PASSWORD")?.trim().orEmpty()
    if (envStorePassword.isEmpty() || envKeyAlias.isEmpty() || envKeyPassword.isEmpty()) {
        throw GradleException(
            "ARCHIVEME_ANDROID_KEYSTORE_FILE is set but one or more of " +
                "ARCHIVEME_ANDROID_KEYSTORE_PASSWORD, ARCHIVEME_ANDROID_KEY_ALIAS, " +
                "ARCHIVEME_ANDROID_KEY_PASSWORD is missing.",
        )
    }
    val storeFile = File(envStoreFile)
    if (!storeFile.isFile) {
        throw GradleException(
            "ARCHIVEME_ANDROID_KEYSTORE_FILE does not exist: ${storeFile.absolutePath}",
        )
    }
    return ReleaseSigningCredentials(
        storeFile = storeFile,
        storePassword = envStorePassword,
        keyAlias = envKeyAlias,
        keyPassword = envKeyPassword,
    )
}

val releaseSigningCredentials = loadReleaseSigningCredentials(rootProject.projectDir)

android {
    namespace = "com.voicememory.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.voicememory.mobile"
        // minSdk 26 — satisfies llama_cpp_dart (24), SQLCipher/sqflite (21),
        // sherpa-onnx (21), and ONNX Runtime (21).
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigningCredentials?.let { creds ->
            create("release") {
                keyAlias = creds.keyAlias
                keyPassword = creds.keyPassword
                storePassword = creds.storePassword
                storeFile = creds.storeFile
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningCredentials != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // When credentials are absent, do not assign any signingConfig here.
            // verifyProductionReleaseSigning fails release tasks before packaging.
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

fun Task.isReleaseArtifactTask(): Boolean {
    if (!name.contains("Release", ignoreCase = true)) {
        return false
    }
    return name == "assembleRelease" ||
        name == "bundleRelease" ||
        name == "packageRelease" ||
        name.startsWith("assembleRelease") ||
        name.startsWith("bundleRelease") ||
        name.startsWith("packageRelease") ||
        name.startsWith("signRelease") ||
        name.endsWith("ReleaseBundle") ||
        name.contains("ReleaseApk", ignoreCase = true)
}

fun verifyProductionReleaseSigning(
    releaseSigningCredentials: ReleaseSigningCredentials?,
    tasks: List<Task>,
) {
    if (releaseSigningCredentials != null) {
        return
    }
    val blocked = tasks.filter { it.isReleaseArtifactTask() }
    if (blocked.isNotEmpty()) {
        throw GradleException(
            "\n" +
                "Release signing is not configured — this build cannot produce a Play Store artifact.\n" +
                "\n" +
                "Configure ONE of:\n" +
                "  • android/key.properties (copy from android/key.properties.example), or\n" +
                "  • ARCHIVEME_ANDROID_KEYSTORE_FILE + ARCHIVEME_ANDROID_KEYSTORE_PASSWORD +\n" +
                "    ARCHIVEME_ANDROID_KEY_ALIAS + ARCHIVEME_ANDROID_KEY_PASSWORD\n" +
                "\n" +
                "Debug builds are unaffected. See docs/ANDROID_RELEASE_CHECKLIST.md.\n" +
                "Blocked release task(s): ${blocked.joinToString { it.path }}\n",
        )
    }
}

gradle.taskGraph.whenReady {
    verifyProductionReleaseSigning(releaseSigningCredentials, allTasks)
}
