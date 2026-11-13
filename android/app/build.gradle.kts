import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google OAuth callback scheme: the reversed client ID, from --dart-define=GOOGLE_CLIENT_ID (never committed).
val googleClientId = (project.findProperty("dart-defines") as String? ?: "")
    .split(",")
    .filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it)) }
    .firstOrNull { it.startsWith("GOOGLE_CLIENT_ID=") }
    ?.substringAfter("=")
    ?.removeSuffix(".apps.googleusercontent.com")

// Microsoft OAuth callback scheme: msal<client ID>, from --dart-define=MICROSOFT_CLIENT_ID (never committed).
val microsoftClientId = (project.findProperty("dart-defines") as String? ?: "")
    .split(",")
    .filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it)) }
    .firstOrNull { it.startsWith("MICROSOFT_CLIENT_ID=") }
    ?.substringAfter("=")

android {
    namespace = "com.cbucciarelli.postino"
    // flutter_local_notifications 23 e androidx.core 1.19 compilano contro le API 37; il target resta quello di Flutter.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (#39) needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cbucciarelli.postino"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleAuthScheme"] =
            googleClientId?.let { "com.googleusercontent.apps.$it" } ?: "com.cbucciarelli.postino.oauth"
        manifestPlaceholders["microsoftAuthScheme"] =
            microsoftClientId?.let { "msal$it" } ?: "com.cbucciarelli.postino.microsoft"
        // llamadart has no armeabi-v7a runtime (ADR 0015): ship only 64-bit ABIs.
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }

    // The Flutter plugin re-adds armeabi-v7a to abiFilters (its default targets), so also drop it at packaging.
    packaging { jniLibs { excludes += "lib/armeabi-v7a/**" } }

    // Upload key for the sideloaded APK (#121): set only by the release workflow (tool/release/android_keystore.sh
    // and the ANDROID_* secrets). Without it, release builds keep the debug keys so `flutter run --release` works.
    val releaseKeystore = System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotEmpty() }
    if (releaseKeystore != null) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (releaseKeystore != null) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications (#39): the desugaring library its README asks for.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
