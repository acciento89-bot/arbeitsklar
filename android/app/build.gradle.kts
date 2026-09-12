plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val launcherResDir = file("src/main/res/drawable-nodpi")
val generatedLauncherIcon = launcherResDir.resolve("arbeitsklar_store_icon.png")
val generateStoreLauncherIcon by tasks.registering(Copy::class) {
    from(rootProject.projectDir.parentFile.resolve("store/google-play/icon-512.png"))
    into(launcherResDir)
    rename { "arbeitsklar_store_icon.png" }
}

android {
    namespace = "de.kamilunavo.arbeitsklar"
    compileSdk = 36
    defaultConfig {
        applicationId = "de.kamilunavo.arbeitsklar"
        minSdk = 26
        targetSdk = 36
        versionCode = 6
        versionName = "1.0.3"
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

tasks.named("preBuild").configure { dependsOn(generateStoreLauncherIcon) }

tasks.register("verifyLauncherIconParity") {
    dependsOn(generateStoreLauncherIcon)
    doLast {
        val storeIcon = rootProject.projectDir.parentFile.resolve("store/google-play/icon-512.png")
        check(storeIcon.readBytes().contentEquals(generatedLauncherIcon.readBytes())) {
            "Android launcher icon must be byte-identical to the Google Play icon"
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
}
