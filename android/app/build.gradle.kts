import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.example.screenjail"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.screenjail"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"

        // 初期値として入るサーバー URL（アプリの画面で変更できる）
        buildConfigField("String", "DEFAULT_SERVER_URL", "\"https://precision-map-wildness.ngrok-free.dev\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.okhttp)
}
