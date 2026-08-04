import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val genesisIncludesLegacyAbis =
    System.getenv("GENESIS_ANDROID_LEGACY_ABIS") == "true"
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val requiredSigningProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties =
    requiredSigningProperties.filter {
        (keystoreProperties.getProperty(it) ?: "").isBlank()
    }
val configuredStoreFile =
    keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
val resolvedStoreFile = configuredStoreFile?.let(::file)
val releaseSigningError =
    when {
        !keystorePropertiesFile.exists() ->
            "android/key.properties is missing."
        missingSigningProperties.isNotEmpty() ->
            "android/key.properties is incomplete; missing: ${missingSigningProperties.joinToString()}."
        resolvedStoreFile == null || !resolvedStoreFile.isFile ->
            "Android release keystore does not exist: ${configuredStoreFile ?: "<missing storeFile>"}."
        else -> null
    }
val hasReleaseSigning = releaseSigningError == null
val productionReleaseRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains(
            Regex(
                "(?i)(assemble|bundle|package).*release|verifyProductionReleaseSigning",
            ),
        )
    }
if (productionReleaseRequested && releaseSigningError != null) {
    throw GradleException(
        "Production Android release signing is required: $releaseSigningError " +
            "Debug signing is never used for release artifacts.",
    )
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += if (genesisIncludesLegacyAbis) {
                listOf("armeabi-v7a", "arm64-v8a", "x86_64")
            } else {
                listOf("arm64-v8a", "x86_64")
            }
        }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DGGML_NATIVE=OFF",
                    "-DLLAMA_BUILD_TESTS=OFF",
                    "-DLLAMA_BUILD_EXAMPLES=OFF",
                    "-DLLAMA_BUILD_SERVER=OFF",
                )
                targets += "llama_mobile"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.register("verifyProductionReleaseSigning") {
    group = "verification"
    description = "Fails unless complete production Android signing is configured."
    doLast {
        if (releaseSigningError != null) {
            throw GradleException(
                "Production Android release signing is required: $releaseSigningError",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}
