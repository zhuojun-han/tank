plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter forwards its -t entrypoint as Gradle -Ptarget (including absolute
// Windows paths). Derive the separate package from that actual entrypoint so
// `flutter build apk -t lib/main_webview.dart` cannot replace the legacy app.
// The explicit property also supports native-only Gradle compilation checks.
val flutterEntrypoint = providers.gradleProperty("target").orNull
    .orEmpty().replace('\\', '/').substringAfterLast('/')
val localWebApp = flutterEntrypoint.equals("main_webview.dart", ignoreCase = true) ||
    providers.gradleProperty("lanjiaoWebView").orNull == "true"
val mobileWebsite = rootProject.file("../../web-demo/dist-mobile")
val webviewAssets = layout.projectDirectory.dir("src/webviewAssets")

android {
    namespace = "com.lanjiao.lanjiao_water_quality"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lanjiao.lanjiao_water_quality"
        if (localWebApp) applicationIdSuffix = ".webview"
        manifestPlaceholders["appLabel"] = if (localWebApp) "澜礁 · 网页版" else "澜礁水质助手"
        buildConfigField("boolean", "LOCAL_WEB_APP", localWebApp.toString())
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_local_notifications 21+ requires Android 7.0 (API 24).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    if (localWebApp) sourceSets.getByName("main").assets.srcDir(webviewAssets)

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.webkit:webkit:1.14.0")
}

if (localWebApp) {
    val packageLocalWebsite by tasks.registering(Sync::class) {
        from(mobileWebsite)
        into(webviewAssets.dir("www"))
        doFirst {
            check(mobileWebsite.resolve("index.html").isFile) {
                "Local website missing: run npm run build:mobile in web-demo first."
            }
        }
    }
    tasks.named("preBuild").configure { dependsOn(packageLocalWebsite) }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
