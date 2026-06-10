buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1") // 🔥 Üsttekiyle birebir eşitlendi
        classpath("com.google.gms:google-services:4.4.2") 
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20") // 🔥 Kotlin sürümü eşitlendi
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Temizleme görevi modern Kotlin DSL formatında
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}