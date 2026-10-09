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
    if (name == "android_file_picker") {
        // The plugin pins AGP 8.5.2, whose SDK parser cannot read SDK XML v4.
        // Use the app's AGP version until the plugin removes its legacy pin.
        buildscript.configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("9.0.1")
                }
            }
        }
    }
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    // Only redirect build dir when source and target share the same drive root.
    // This prevents Path.relativize() failures on Windows when plugins come from
    // a different drive (e.g. Pub cache on C: vs project on D:).
    val srcRoot = project.projectDir.toPath().root
    val dstRoot = newSubprojectBuildDir.asFile.toPath().root
    if (srcRoot == dstRoot) {
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
