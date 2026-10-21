plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val iosLauncherIcon = rootProject.projectDir.parentFile.resolve("ArbeitsKlar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
val androidLauncherIcon = file("src/main/res/drawable-nodpi/arbeitsklar_store_icon.png")

android {
    namespace = "de.kamilunavo.arbeitsklar"
    compileSdk = 36
    defaultConfig {
        applicationId = "de.kamilunavo.arbeitsklar"
        minSdk = 26
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        versionCode = 7
        versionName = "1.1.0"
    }
    buildFeatures { compose = true; buildConfig = true }
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

tasks.register("verifyLauncherIconParity") {
    doLast {
        check(iosLauncherIcon.readBytes().contentEquals(androidLauncherIcon.readBytes())) {
            "Android launcher icon must be byte-identical to the canonical iOS app icon"
        }
    }
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
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
