allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build directory path adjustment
val baseBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(baseBuildDir)

subprojects {
    val subprojectBuildDir = baseBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}