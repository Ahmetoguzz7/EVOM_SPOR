plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.EVOM_SPOR"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.EVOM_SPOR"
        minSdk = flutter.minSdkVersion  
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging")
}

// 🔥🔥🔥 APK ÇIKTI YOLUNU FLUTTER'IN BEKLEDİĞİ YERE YÖNLENDİR 🔥🔥🔥
afterEvaluate {
    tasks.named("assembleRelease").configure {
        doLast {
            val sourceApk = file("build/outputs/apk/release/app-release.apk")
            val targetDir = file("../../build/app/outputs/flutter-apk")
            val targetApk = file("../../build/app/outputs/flutter-apk/app-release.apk")
            
            if (sourceApk.exists()) {
                targetDir.mkdirs()
                sourceApk.copyTo(targetApk, overwrite = true)
                println("✅ APK kopyalandı: ${targetApk.absolutePath}")
            } else {
                println("❌ Kaynak APK bulunamadı: ${sourceApk.absolutePath}")
            }
        }
    }
    
    tasks.named("assembleDebug").configure {
        doLast {
            val sourceApk = file("build/outputs/apk/debug/app-debug.apk")
            val targetDir = file("../../build/app/outputs/flutter-apk")
            val targetApk = file("../../build/app/outputs/flutter-apk/app-debug.apk")
            
            if (sourceApk.exists()) {
                targetDir.mkdirs()
                sourceApk.copyTo(targetApk, overwrite = true)
                println("✅ APK kopyalandı: ${targetApk.absolutePath}")
            } else {
                println("❌ Kaynak APK bulunamadı: ${sourceApk.absolutePath}")
            }
        }
    }
}