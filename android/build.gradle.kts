val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // Ensure we only resolve ONE Mapbox Maps implementation on Android.
    // `mapbox_maps_flutter` uses `*-ndk27` artifacts; Mapbox Navigation UI pulls the non-ndk27 ones.
    // Having both produces duplicate classes.
    // Keep this aligned with what Mapbox Navigation requests.
    val mapboxMapsVersion = "11.17.1"
    // Keep this aligned with the Mapbox Maps version's underlying Common version.
    val mapboxCommonVersion = "24.17.1"
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            val group = requested.group ?: return@eachDependency
            if (
                group == "com.mapbox.maps" ||
                group == "com.mapbox.plugin" ||
                group == "com.mapbox.extension" ||
                group == "com.mapbox.module"
            ) {
                useVersion(mapboxMapsVersion)
            }
        }

        resolutionStrategy.dependencySubstitution {
            // Mapbox Common: force ndk27 to avoid duplicate classes (common vs common-ndk27)
            substitute(module("com.mapbox.common:common")).using(module("com.mapbox.common:common-ndk27:$mapboxCommonVersion"))

            // Core Maps artifacts
            substitute(module("com.mapbox.maps:android")).using(module("com.mapbox.maps:android-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.maps:base")).using(module("com.mapbox.maps:base-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.maps:android-core")).using(module("com.mapbox.maps:android-core-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.maps:common")).using(module("com.mapbox.maps:common-ndk27:$mapboxMapsVersion"))

            // Plugins
            substitute(module("com.mapbox.plugin:maps-annotation")).using(module("com.mapbox.plugin:maps-annotation-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-attribution")).using(module("com.mapbox.plugin:maps-attribution-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-animation")).using(module("com.mapbox.plugin:maps-animation-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-compass")).using(module("com.mapbox.plugin:maps-compass-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-gestures")).using(module("com.mapbox.plugin:maps-gestures-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-lifecycle")).using(module("com.mapbox.plugin:maps-lifecycle-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-locationcomponent")).using(module("com.mapbox.plugin:maps-locationcomponent-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-logo")).using(module("com.mapbox.plugin:maps-logo-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-overlay")).using(module("com.mapbox.plugin:maps-overlay-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-scalebar")).using(module("com.mapbox.plugin:maps-scalebar-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.plugin:maps-viewport")).using(module("com.mapbox.plugin:maps-viewport-ndk27:$mapboxMapsVersion"))

            // Extensions/modules
            substitute(module("com.mapbox.extension:maps-localization")).using(module("com.mapbox.extension:maps-localization-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.extension:maps-style")).using(module("com.mapbox.extension:maps-style-ndk27:$mapboxMapsVersion"))
            substitute(module("com.mapbox.module:maps-telemetry")).using(module("com.mapbox.module:maps-telemetry-ndk27:$mapboxMapsVersion"))
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
