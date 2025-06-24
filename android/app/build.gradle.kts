// android/app/build.gradle.kts (App Level)
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.vc"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.nitin.vc"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ CORRECTED AND SIMPLIFIED signingConfigs block
    // The 'debug' signingConfig is provided by Gradle by default.
    // You only need to 'create' custom ones like 'release'.
    signingConfigs {
        create("release") {
            // TODO: Define your production release signing config here!
            // Example (replace with your actual paths and variables):
            // storeFile = file("path/to/your/release.keystore")
            // storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_store_password"
            // keyAlias = System.getenv("KEY_ALIAS") ?: "your_key_alias"
            // keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
        }
    }

    // ✅ CORRECTED buildTypes block
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") // Refer to the created release config
            isMinifyEnabled = true // Enable code shrinking for release builds
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug { // This 'debug' block defines the 'debug' build type
            signingConfig = signingConfigs.getByName("debug") // Refer to Gradle's default 'debug' signing config
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    ndkVersion = "27.0.12077973"
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // REMOVED: implementation("com.google.firebase:firebase-messaging:23.2.1")
    // As discussed, prefer FlutterFire plugins to manage Firebase SDK versions automatically.
}