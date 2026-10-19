plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A test build that installs next to the normal app instead of updating it:
//   SPLITKIT_APP_ID_SUFFIX=.beta flutter build apk --dart-define=API_ORIGIN=http://<laptop>:8000
// Android treats another application id as another app (own data, own login). Unset, nothing
// changes.
val betaSuffix = System.getenv("SPLITKIT_APP_ID_SUFFIX").orEmpty()

android {
    namespace = "com.splitkit.splitkit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.splitkit.splitkit" + betaSuffix
        // A beta (SPLITKIT_APP_ID_SUFFIX set) is its own app, "Splitkit Beta", and may reach a
        // server over plain HTTP: a laptop on the same Wi-Fi. The normal app does neither.
        manifestPlaceholders["appLabel"] = if (betaSuffix.isEmpty()) "splitkit" else "Splitkit Beta"
        manifestPlaceholders["usesCleartextTraffic"] = betaSuffix.isNotEmpty().toString()
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

flutter {
    source = "../.."
}
