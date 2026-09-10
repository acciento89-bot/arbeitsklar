plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val uploadKeystorePath = System.getenv("ANDROID_UPLOAD_KEYSTORE_PATH")
val uploadStorePassword = System.getenv("ANDROID_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = System.getenv("ANDROID_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = System.getenv("ANDROID_UPLOAD_KEY_PASSWORD")

android {
    namespace = "de.kamilunavo.arbeitsklar"
    compileSdk = 36
    defaultConfig {
        applicationId = "de.kamilunavo.arbeitsklar"
        minSdk = 26
        targetSdk = 36
        versionCode = 5
        versionName = "1.0.2"
    }
    buildFeatures { compose = true; buildConfig = true }

    signingConfigs {
        create("releaseUpload") {
            if (!uploadKeystorePath.isNullOrBlank()) {
                storeFile = file(uploadKeystorePath)
                storeType = "JKS"
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (!uploadKeystorePath.isNullOrBlank()) {
                signingConfig = signingConfigs.getByName("releaseUpload")
            }
        }
    }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("com.android.billingclient:billing-ktx:9.1.0")
    testImplementation("junit:junit:4.13.2")
}
