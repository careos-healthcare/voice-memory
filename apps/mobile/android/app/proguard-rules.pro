# SQLCipher — encrypted local journal (sqflite_sqlcipher)
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# OkHttp / Okio — transitive Android HTTP stack (Firebase, RevenueCat, etc.)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.internal.platform.** { *; }

# Retrofit 2 — guards Java/Kotlin HTTP clients pulled in by Android dependencies.
# Dart Dio/Retrofit clients are not obfuscated by R8; these rules prevent release
# crashes when plugins ship Retrofit/OkHttp on the classpath.
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# Gson — JSON adapters for Android-side HTTP clients
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ONNX Runtime — local STT / embedding inference (flutter_onnxruntime)
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Flutter embedding and plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# RevenueCat in-app purchases
-keep class com.revenuecat.purchases.** { *; }

# Kotlin coroutines / serialization
-dontwarn kotlinx.**
-keepclassmembers class kotlinx.** {
    volatile <fields>;
}
