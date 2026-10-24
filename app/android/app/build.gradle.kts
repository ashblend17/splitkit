plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The app's id and name on the phone: APP_ID and APP_NAME, from the environment or the repo's
// .env (as docker compose and tool/build.sh read it). Another id is another app on a phone (its
// own data and login), so keep it once the app is installed anywhere.
val dotEnv: Map<String, String> = rootProject.file("../../.env").let { f ->
    if (!f.exists()) emptyMap() else f.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { it.substringBefore("=").trim() to it.substringAfter("=").trim().trim('"', '\'') }
}
fun setting(key: String, default: String) = System.getenv(key) ?: dotEnv[key] ?: default
val appId = setting("APP_ID", "com.example.app")
val appName = setting("APP_NAME", "App")

// A test build that installs next to the normal app instead of updating it:
//   APP_ID_SUFFIX=.beta flutter build apk --dart-define=API_ORIGIN=http://<laptop>:8000
// Android treats another application id as another app (own data, own login). Unset, nothing
// changes.
val betaSuffix = System.getenv("APP_ID_SUFFIX").orEmpty()

android {
    namespace = "com.example.app"
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
        applicationId = appId + betaSuffix
        // A beta (APP_ID_SUFFIX set) is its own app, "<name> Beta", and may reach a server over
        // plain HTTP: a laptop on the same Wi-Fi. The normal app does neither.
        manifestPlaceholders["appLabel"] = if (betaSuffix.isEmpty()) appName else "$appName Beta"
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
