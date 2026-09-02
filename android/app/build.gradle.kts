import com.android.build.gradle.internal.dsl.BaseAppModuleExtension

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.last_version_test"  // ✅ نام پکیج خود را وارد کنید
    compileSdk = 36  // ✅ SDK 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.last_version_test"  // ✅ نام پکیج خود را وارد کنید
        minSdk = 21
        targetSdk = 36  // ✅ SDK 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version")
}