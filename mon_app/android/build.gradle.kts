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
// audioplayers_android 5.x ne déclare pas compileSdk : on le fixe pour les plugins qui l'oublient
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.getByName("android")
        val getter = android.javaClass.getMethod("getCompileSdk")
        if (getter.invoke(android) == null) {
            android.javaClass.getMethod("setCompileSdk", Integer::class.java).invoke(android, 36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
