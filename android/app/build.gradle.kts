plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.somi_app"

    // Google ya no publica un `platforms;android-37` "pelado": el SDK de
    // Android 17 se llama `android-37.0` (versionado con minor). AGP 9 sólo
    // lo encuentra si se le pasa el minor por separado; con `compileSdk = 37`
    // a secas busca el hash `android-37` y el build falla con
    // "Failed to find target with hash string 'android-37'".
    //
    // Se compila contra 37.0 porque flutter_secure_storage y
    // permission_handler_android piden API 37 (ver el ajuste equivalente para
    // los plugins en ../build.gradle.kts). targetSdk sigue siendo el default
    // de Flutter, así que el comportamiento en runtime no cambia.
    compileSdk = 37
    compileSdkMinor = 0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.somi_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
