buildscript {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }
    dependencies {
        // IMPORTANT: Updated google-services plugin to the latest stable version
        // Always check the Firebase documentation for the absolute latest version:
        // https://firebase.google.com/docs/android/setup
        classpath("com.google.gms:google-services:4.4.1") // This is the Google Services plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
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