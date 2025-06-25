// android/build.gradle.kts (Root Project)
buildscript {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io") // Keep if you explicitly need Jitpack
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.0") // Or your current AGP version, ensure it's up to date
        // UPDATE THIS LINE: Kotlin Gradle plugin to 2.0.0 for compatibility
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0")
        classpath("com.google.gms:google-services:4.4.1") // Google Services plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // If you had jcenter() here, ensure it's removed as it's deprecated.
    }
}

// Optional: Customize build directory (used in your current setup)
// Keep this as is, assuming it's intentional for your project structure.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}