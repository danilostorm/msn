plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The signing secret is supplied by the deployment host and never committed.
val stormReleaseKeystore = System.getenv("STORM_MSN_RELEASE_KEYSTORE")
val stormReleasePassword = System.getenv("STORM_MSN_RELEASE_PASSWORD")

android {
    namespace = "cloud.hoststorm.storm_msn_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cloud.hoststorm.storm_msn_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID"] = System.getenv("STORM_ADMOB_APP_ID")?.takeIf { it.matches(Regex("""ca-app-pub-[0-9]+~[0-9]+""")) } ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("stormRelease") {
            if (!stormReleaseKeystore.isNullOrBlank() && !stormReleasePassword.isNullOrBlank()) {
                storeFile = file(stormReleaseKeystore)
                storePassword = stormReleasePassword
                keyAlias = "stormmsn"
                keyPassword = stormReleasePassword
            }
        }
    }

    buildTypes {
        release {
            val officialRelease = gradle.startParameter.taskNames.any { task ->
                task.contains("Release", ignoreCase = true)
            }
            if (officialRelease) {
                require(!stormReleaseKeystore.isNullOrBlank() && !stormReleasePassword.isNullOrBlank()) {
                    "Storm MSN official release requires signing credentials on the build host."
                }
            }
            signingConfig = if (!stormReleaseKeystore.isNullOrBlank() && !stormReleasePassword.isNullOrBlank()) {
                signingConfigs.getByName("stormRelease")
            } else {
                signingConfigs.getByName("debug") // only for local/debug configuration
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
