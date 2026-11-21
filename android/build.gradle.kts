allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// solana_mobile_client 0.1.x and coinbase_wallet_sdk are compiled against android-31, but their AndroidX deps need 34+.
subprojects {
    if (project.name in setOf("solana_mobile_client", "coinbase_wallet_sdk")) {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.compileSdk = 35
            // A coinbase_wallet_sdk 1.0.10 olyan consumer-rules.pro-t jelöl meg, ami nincs a csomagban.
            val rules = file("consumer-rules.pro")
            if (project.name == "coinbase_wallet_sdk" && !rules.exists()) rules.createNewFile()
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
