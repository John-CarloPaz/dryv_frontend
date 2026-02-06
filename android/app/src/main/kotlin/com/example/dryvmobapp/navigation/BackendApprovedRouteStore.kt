package com.example.dryvmobapp.navigation

import com.mapbox.geojson.Point

/**
 * In-memory storage of the backend-approved route.
 *
 * SAFETY:
 * - This app must strictly follow the backend-approved route.
 * - Android navigation must never request new routes or reroute.
 */
object BackendApprovedRouteStore {
    @Volatile
    var directionsRouteJson: String? = null
        private set

    @Volatile
    var coordinates: List<Point> = emptyList()
        private set

    @Volatile
    var waypointIndices: List<Int> = emptyList()
        private set

    fun set(
        directionsRouteJson: String?,
        coordinates: List<Point>,
        waypointIndices: List<Int>,
    ) {
        this.directionsRouteJson = directionsRouteJson
        this.coordinates = coordinates
        this.waypointIndices = waypointIndices
    }

    fun clear() {
        directionsRouteJson = null
        coordinates = emptyList()
        waypointIndices = emptyList()
    }

    fun isReady(): Boolean {
        return coordinates.size >= 2
    }
}
