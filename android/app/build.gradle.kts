import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    FileInputStream(signingPropertiesFile).use(signingProperties::load)
}
val hasReleaseSigning = signingPropertiesFile.exists()
val testAdsRequested = providers.gradleProperty("HUHS_ENABLE_TEST_ADS")
    .map(String::toBoolean)
    .orElse(false)
    .get()
val productionAdMobAppId = providers.gradleProperty("HUHS_ADMOB_APP_ID").orNull
val productionAdMobBannerId = providers.gradleProperty("HUHS_ADMOB_BANNER_ID").orNull
val productionAdMobRewardedId = providers.gradleProperty("HUHS_ADMOB_REWARDED_ID").orNull
val isReleaseTask = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (isReleaseTask && !testAdsRequested) {
    val missing = buildList {
        if (productionAdMobAppId.isNullOrBlank()) add("HUHS_ADMOB_APP_ID")
        if (productionAdMobBannerId.isNullOrBlank()) add("HUHS_ADMOB_BANNER_ID")
        if (productionAdMobRewardedId.isNullOrBlank()) add("HUHS_ADMOB_REWARDED_ID")
        if (!hasReleaseSigning) add("key.properties/release signing")
    }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Production release build requires: ${missing.joinToString()}. " +
                "Use -PHUHS_ENABLE_TEST_ADS=true only for an explicit test build."
        )
    }
}

android {
    namespace = "com.example.hungarian_hardstyle_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.hungarian_hardstyle_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["adMobAppId"] = if (testAdsRequested) {
            "ca-app-pub-3940256099942544~3347511713"
        } else {
            productionAdMobAppId.orEmpty()
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = signingProperties["keyAlias"] as String
                keyPassword = signingProperties["keyPassword"] as String
                storeFile = file(signingProperties["storeFile"] as String)
                storePassword = signingProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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
