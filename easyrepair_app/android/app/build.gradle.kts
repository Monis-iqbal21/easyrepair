import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase — requires google-services.json placed in android/app/
    // Get it from: Firebase Console → Project Settings → Add Android app → download google-services.json
    id("com.google.gms.google-services")
}

// ---------------------------------------------------------------------------
// Release signing — values are loaded from android/key.properties (not in VCS)
// Copy key.properties.example → key.properties and fill in your keystore details.
// ---------------------------------------------------------------------------
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

// ---------------------------------------------------------------------------
// Google Maps API key — `flutter run`/`flutter build` never forward
// --dart-define values into the native Gradle build (dart-define only
// reaches Dart's String.fromEnvironment), so the manifest placeholder below
// was silently resolving to "" whenever it relied only on a -P flag or env
// var — this is what produced a blank/empty Google Map box at runtime.
// Add GOOGLE_MAPS_API_KEY=<key> to android/local.properties (gitignored,
// machine-local — same file that already holds sdk.dir) as the simplest fix.
// ---------------------------------------------------------------------------
val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

android {
    namespace = "ai.handygo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = keyProperties["storeFile"]?.let { file(it) }
            storePassword = keyProperties["storePassword"] as String?
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "ai.handygo.app"
        // Use the SDK floor supported by this Flutter toolchain and all plugins.
        // The configured Flutter SDK currently supplies API 24.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)
            ?: System.getenv("GOOGLE_MAPS_API_KEY")
            ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
            ?: ""
    }

    buildTypes {
        release {
            // TEMP APK FIX:
            // Disable R8/minify to avoid missing Google Play Core splitinstall classes
            // during release APK build.
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Never allow a production artifact to be signed with the debug key.
            // A release build must fail until android/key.properties is configured.
            signingConfig = signingConfigs.getByName("release")
        }

        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Fail release builds early with an actionable error. Release signing remains
// unconditional above, so this never falls back to the debug signing key.
gradle.taskGraph.whenReady {
    val thisModule = "${project.path}:"
    val buildingRelease = allTasks.any { task ->
        task.path.startsWith(thisModule) && task.name.contains("Release")
    }
    if (buildingRelease && !keyPropertiesFile.exists()) {
        throw GradleException(
            "key.properties missing — release builds require the configured release key.\n" +
                "  expected at: ${keyPropertiesFile.absolutePath}\n" +
                "  fix: copy android/key.properties.example -> android/key.properties " +
                "and fill in storeFile / storePassword / keyAlias / keyPassword.\n" +
                "  (debug builds and `flutter run` are unaffected.)",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
