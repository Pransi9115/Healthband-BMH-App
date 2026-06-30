plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bmh_app"
    compileSdk = flutter.compileSdkVersion.toInteger()
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.example.bmh_app"
        minSdk = flutter.minSdkVersion.toInteger()
        targetSdk = flutter.targetSdkVersion.toInteger()
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}