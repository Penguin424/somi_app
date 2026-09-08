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

// Los plugins que piden `compileSdk = 37` (hoy flutter_secure_storage y
// permission_handler_android) no compilan con AGP 9: buscan el hash
// `android-37`, que Google no publica — el SDK instalado es `android-37.0`.
// Como no se pueden editar los build.gradle de los plugins, se les completa
// el minor acá, igual que hace app/build.gradle.kts para el módulo :app.
//
// Se usa reflexión a propósito: el DSL de AGP no está en el classpath de este
// script, y así el bloque queda como no-op si algún día AGP deja de exponer
// `compileSdkMinor`.
fun Project.completarCompileSdkMinor() {
    val androidExt = extensions.findByName("android") ?: return
    try {
        val clazz = androidExt.javaClass
        val compileSdk = clazz.getMethod("getCompileSdk").invoke(androidExt) as? Int
        val compileSdkMinor = clazz.getMethod("getCompileSdkMinor").invoke(androidExt) as? Int
        if (compileSdk != null && compileSdk >= 37 && compileSdkMinor == null) {
            clazz.getMethod("setCompileSdkMinor", Integer::class.java).invoke(androidExt, 0)
            logger.lifecycle("[somi_app] ${name}: compileSdk $compileSdk -> $compileSdk.0")
        }
    } catch (_: NoSuchMethodException) {
        // AGP sin soporte de compileSdkMinor: no hay nada que ajustar.
    }
}

// Este bloque va antes del `evaluationDependsOn(":app")` de abajo: ese fuerza
// la evaluación de :app, y registrar un `afterEvaluate` sobre un proyecto ya
// evaluado tira "Cannot run Project.afterEvaluate(Action)".
subprojects {
    if (state.executed) {
        completarCompileSdkMinor()
    } else {
        afterEvaluate { completarCompileSdkMinor() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
