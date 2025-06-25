// android/app/build.gradle.kts (App Level)
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    
}

android {
    namespace = "com.nitin.vc"
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
   
    // >>>>> ENSURE THESE FIREBASE DEPENDENCIES ARE PRESENT AND UNCOMMENTED <<<<<
    // Import the Firebase BoM (Bill of Materials)
    // This ensures all your Firebase libraries use compatible versions.
    // ALWAYS CHECK THE LATEST STABLE VERSION ON FIREBASE DOCUMENTATION!
    implementation(project.dependencies.platform("com.google.firebase:firebase-bom:33.15.0"))

    // Add the dependencies for the Firebase products your app uses.
    // When using the BoM, you DO NOT specify versions for these individual Firebase libraries:
    implementation("com.google.firebase:firebase-auth")       // For Firebase Authentication
    implementation("com.google.firebase:firebase-firestore")  // For Cloud Firestore
    implementation("com.google.firebase:firebase-messaging")  // For Firebase Cloud Messaging
    // Add any other Firebase products your app uses here (e.g., firebase-analytics, firebase-storage, etc.)
}