import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-key credentials for Play Store release builds. android/key.properties
// is gitignored and must never be committed — see
// https://docs.flutter.dev/deployment/android#configure-signing-in-gradle
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.royalhrms.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent Play Store identity — never change after the first upload.
        applicationId = "com.royalhrms.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Always the upload key — never a silent debug-signing fallback
            // (a debug-signed bundle cannot be uploaded to Play). Missing or
            // incomplete credentials fail the release build below instead.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Fails any release build early, with a clear message, when the upload-key
// credentials are missing; debug and profile builds are unaffected.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (!buildsRelease) return@whenReady
    val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missing = if (!keystorePropertiesFile.exists()) required
        else required.filter { (keystoreProperties[it] as String?).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Release signing is not configured: android/key.properties is missing or lacks " +
                missing.joinToString() + ". Release builds are never signed with the debug key. " +
                "See https://docs.flutter.dev/deployment/android#configure-signing-in-gradle"
        )
    }
    val store = file(keystoreProperties["storeFile"] as String)
    if (!store.exists()) {
        throw GradleException("Release signing keystore not found at the storeFile path in android/key.properties.")
    }
}

flutter {
    source = "../.."
}
