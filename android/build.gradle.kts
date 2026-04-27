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
// Paste this right here:
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.configure<com.android.build.gradle.BaseExtension> {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
            }
        }
    }
}

// This is the line that was already in your file:
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

