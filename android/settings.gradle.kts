System.clearProperty("ANDROID_PREFS_ROOT")
System.clearProperty("android.prefs.root")

try {
    val peClass = Class.forName("java.lang.ProcessEnvironment")

    listOf("theEnvironment", "theCaseInsensitiveEnvironment", "theUnmodifiableEnvironment").forEach { fieldName ->
        try {
            val field = peClass.getDeclaredField(fieldName)
            field.isAccessible = true
            val map = field.get(null) as? MutableMap<*, *>
            map?.keys?.removeAll { key -> key.toString().equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
        } catch (ignored: Throwable) {}
    }
} catch (ignored: Throwable) {}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.4.2" apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
