package com.example.dryvmobapp.navigation

import android.os.Bundle
import android.view.View
import android.widget.Toast
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import com.example.dryvmobapp.R
import com.mapbox.common.MapboxOptions
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.common.location.Location
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.MapView
import com.mapbox.maps.Style
import com.mapbox.maps.plugin.animation.camera
import com.mapbox.maps.plugin.locationcomponent.createDefault2DPuck
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.maps.plugin.scalebar.scalebar
import com.mapbox.geojson.LineString
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.maps.extension.style.layers.generated.lineLayer
import com.mapbox.maps.extension.style.layers.properties.generated.LineCap
import com.mapbox.maps.extension.style.layers.properties.generated.LineJoin
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.sources.generated.geoJsonSource
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.trip.model.RouteProgress
import com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.core.trip.session.LocationMatcherResult
import com.mapbox.navigation.core.trip.session.LocationObserver
import com.mapbox.navigation.core.trip.session.OffRouteObserver
import com.mapbox.navigation.core.trip.session.RouteProgressObserver
import com.mapbox.navigation.ui.components.maneuver.view.MapboxManeuverView
import com.mapbox.navigation.ui.components.tripprogress.view.MapboxTripProgressView
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.location.NavigationLocationProvider
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineApi
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineView
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineApiOptions
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineViewOptions
import com.mapbox.navigation.core.directions.session.RoutesObserver
import com.mapbox.navigation.core.formatter.MapboxDistanceFormatter
import com.mapbox.navigation.base.formatter.DistanceFormatterOptions
import com.mapbox.navigation.tripdata.maneuver.api.MapboxManeuverApi
import com.mapbox.navigation.tripdata.progress.api.MapboxTripProgressApi
import com.mapbox.navigation.tripdata.progress.model.DistanceRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.EstimatedTimeToArrivalFormatter
import com.mapbox.navigation.tripdata.progress.model.TimeRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.TripProgressUpdateFormatter
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Native turn-by-turn navigation activity using Mapbox Navigation SDK v3.
 *
 * SAFETY-CRITICAL CONSTRAINTS:
 * - Uses ONLY backend-provided route (DirectionsRoute JSON) + waypoints.
 * - Automatic rerouting / refresh / off-route recalculation MUST be disabled.
 * - If user goes off-route, we keep guidance on the approved route and do not request new routes.
 */
@OptIn(ExperimentalPreviewMapboxNavigationAPI::class)
class MapboxNavigationActivity : AppCompatActivity() {

    private val backendRouteSourceId = "dryv-backend-route-source"
    private val backendRouteLayerId = "dryv-backend-route-layer"

    private fun dedupeBackendGeometry(
        input: List<com.mapbox.geojson.Point>,
    ): List<com.mapbox.geojson.Point> {
        if (input.size <= 2) return input
        val out = ArrayList<com.mapbox.geojson.Point>(input.size)
        var last: com.mapbox.geojson.Point? = null
        for (p in input) {
            if (last == null) {
                out.add(p)
                last = p
                continue
            }
            val dLng = abs(p.longitude() - last.longitude())
            val dLat = abs(p.latitude() - last.latitude())
            // ~2m-ish threshold in degrees; removes jitter/duplicates.
            if (dLng < 2e-5 && dLat < 2e-5) continue
            out.add(p)
            last = p
        }
        return if (out.size >= 2) out else input
    }

    private fun showBackendRoutePreview(style: Style) {
        if (!BackendApprovedRouteStore.isReady()) {
            finish()
            return
        }

        val backendGeometry = dedupeBackendGeometry(BackendApprovedRouteStore.coordinates)

        try {
            // Replace existing source/layer if present.
            if (style.styleLayerExists(backendRouteLayerId)) {
                style.removeStyleLayer(backendRouteLayerId)
            }
            if (style.styleSourceExists(backendRouteSourceId)) {
                style.removeStyleSource(backendRouteSourceId)
            }

            val lineString = LineString.fromLngLats(backendGeometry)
            style.addSource(
                geoJsonSource(backendRouteSourceId) {
                    geometry(lineString)
                },
            )

            style.addLayer(
                lineLayer(backendRouteLayerId, backendRouteSourceId) {
                    lineColor("#2F80ED")
                    lineWidth(6.0)
                    lineJoin(LineJoin.ROUND)
                    lineCap(LineCap.ROUND)
                },
            )

            // Fit camera to the backend geometry.
            try {
                val camera = mapView.mapboxMap.cameraForCoordinates(
                    backendGeometry,
                    EdgeInsets(140.0, 60.0, 320.0, 60.0),
                    null,
                    null,
                )
                mapView.mapboxMap.setCamera(camera)
            } catch (e: Exception) {
                // Fallback: center on origin.
                mapView.mapboxMap.setCamera(
                    CameraOptions.Builder()
                        .center(backendGeometry.first())
                        .zoom(14.0)
                        .build(),
                )
            }

            routeLoadingIndicator.visibility = View.GONE
            startDrivingButton.visibility = View.VISIBLE
        } catch (e: Exception) {
            routeLoadingIndicator.visibility = View.GONE
            Toast.makeText(this, "Failed to draw backend route.", Toast.LENGTH_SHORT).show()
            Log.e("DRYV", "Failed to draw backend route", e)
            finish()
        }
    }

    private fun settlePreviewCoordinates(
        input: List<com.mapbox.geojson.Point>,
        // Mapbox Directions has a coordinate/waypoint limit (varies by plan/SDK);
        // using a higher cap makes the computed route adhere much more closely
        // to the backend geometry.
        maxPoints: Int = 25,
    ): List<com.mapbox.geojson.Point> {
        if (input.size <= 2) return input

        // 1) Stable de-dupe for near-identical consecutive points.
        val deduped = ArrayList<com.mapbox.geojson.Point>(input.size)
        var last: com.mapbox.geojson.Point? = null
        for (p in input) {
            if (last == null) {
                deduped.add(p)
                last = p
                continue
            }
            val dLng = abs(p.longitude() - last.longitude())
            val dLat = abs(p.latitude() - last.latitude())
            // ~2m-ish threshold in degrees (rough). Enough to remove jitter/duplicates.
            if (dLng < 2e-5 && dLat < 2e-5) continue
            deduped.add(p)
            last = p
        }

        if (deduped.size <= maxPoints) return deduped

        // 2) Prefer keeping points that represent meaningful progress.
        // Keep a point if:
        // - it's far enough from the last kept point, or
        // - it introduces a significant heading change.
        val simplified = ArrayList<com.mapbox.geojson.Point>(maxPoints)
        simplified.add(deduped.first())
        var lastKept = deduped.first()
        var lastHeading = 0.0

        fun heading(from: com.mapbox.geojson.Point, to: com.mapbox.geojson.Point): Double {
            val lat1 = Math.toRadians(from.latitude())
            val lon1 = Math.toRadians(from.longitude())
            val lat2 = Math.toRadians(to.latitude())
            val lon2 = Math.toRadians(to.longitude())

            val dLon = lon2 - lon1
            val y = sin(dLon) * cos(lat2)
            val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            val brng = atan2(y, x)
            // Normalize to [0, 360)
            return (Math.toDegrees(brng) + 360.0) % 360.0
        }

        fun headingDelta(a: Double, b: Double): Double {
            val diff = abs(a - b) % 360.0
            return if (diff > 180.0) 360.0 - diff else diff
        }

        fun haversineMeters(a: com.mapbox.geojson.Point, b: com.mapbox.geojson.Point): Double {
            val r = 6371000.0
            val lat1 = Math.toRadians(a.latitude())
            val lon1 = Math.toRadians(a.longitude())
            val lat2 = Math.toRadians(b.latitude())
            val lon2 = Math.toRadians(b.longitude())
            val dLat = lat2 - lat1
            val dLon = lon2 - lon1
            val s1 = sin(dLat / 2.0)
            val s2 = sin(dLon / 2.0)
            val h = s1 * s1 + cos(lat1) * cos(lat2) * s2 * s2
            return 2.0 * r * atan2(sqrt(h), sqrt(1.0 - h))
        }

        // Initialize heading from first segment when possible.
        if (deduped.size >= 3) {
            lastHeading = heading(deduped[0], deduped[1])
        }

        // Keep more points to preserve backend-intended turns.
        // If these are too aggressive, Mapbox will choose its own path between
        // sparse shaping points (causing the "extra turns" you saw).
        val minDistanceMeters = 30.0
        val minHeadingDeltaDeg = 10.0
        for (i in 1 until deduped.size - 1) {
            val p = deduped[i]
            val dist = haversineMeters(lastKept, p)
            val hdg = heading(lastKept, p)
            val hdgDelta = headingDelta(lastHeading, hdg)

            if (dist >= minDistanceMeters || hdgDelta >= minHeadingDeltaDeg) {
                simplified.add(p)
                lastKept = p
                lastHeading = hdg
            }
        }
        simplified.add(deduped.last())

        if (simplified.size <= maxPoints) return simplified

        // 3) Downsample evenly if still above maxPoints.
        val out = ArrayList<com.mapbox.geojson.Point>(maxPoints)
        val n = simplified.size
        val step = (n - 1).toDouble() / (maxPoints - 1).toDouble()
        for (i in 0 until maxPoints) {
            val idx = (i * step).toInt().coerceIn(0, n - 1)
            out.add(simplified[idx])
        }

        // Ensure exact endpoints.
        out[0] = simplified.first()
        out[out.size - 1] = simplified.last()
        return out
    }

    private lateinit var mapView: MapView
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var routeLineApi: MapboxRouteLineApi
    private lateinit var routeLineView: MapboxRouteLineView
    private val navigationLocationProvider = NavigationLocationProvider()

    private var maneuverView: MapboxManeuverView? = null
    private var tripProgressView: MapboxTripProgressView? = null
    private lateinit var startDrivingButton: AppCompatButton
    private lateinit var routeLoadingIndicator: View

    private var tripStarted: Boolean = false
    private var pendingPreviewRouteOptions: RouteOptions? = null
    private var previewRequestStarted: Boolean = false

    private val distanceFormatterOptions: DistanceFormatterOptions by lazy {
        DistanceFormatterOptions.Builder(this).build()
    }

    private val maneuverApi: MapboxManeuverApi by lazy {
        MapboxManeuverApi(MapboxDistanceFormatter(distanceFormatterOptions))
    }

    private val tripProgressApi: MapboxTripProgressApi by lazy {
        val formatter = TripProgressUpdateFormatter.Builder(this)
            .distanceRemainingFormatter(DistanceRemainingFormatter(distanceFormatterOptions))
            .timeRemainingFormatter(TimeRemainingFormatter(this))
            .estimatedTimeToArrivalFormatter(EstimatedTimeToArrivalFormatter(this))
            .build()
        MapboxTripProgressApi(formatter)
    }

    private val routesObserver = RoutesObserver { routeUpdateResult ->
        if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
            routeLineApi.setNavigationRoutes(routeUpdateResult.navigationRoutes) { value ->
                mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, value)
                }
            }

            viewportDataSource.onRouteChanged(routeUpdateResult.navigationRoutes.first())
            viewportDataSource.evaluate()
            navigationCamera.requestNavigationCameraToOverview()
        }
    }

    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: Location) = Unit

        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            val enhancedLocation = locationMatcherResult.enhancedLocation

            navigationLocationProvider.changePosition(
                location = enhancedLocation,
                keyPoints = locationMatcherResult.keyPoints,
            )

            viewportDataSource.onLocationChanged(enhancedLocation)
            viewportDataSource.evaluate()
            navigationCamera.requestNavigationCameraToFollowing()
        }
    }

    private val routeProgressObserver = object : RouteProgressObserver {
        override fun onRouteProgressChanged(routeProgress: RouteProgress) {
            maneuverView?.renderManeuvers(maneuverApi.getManeuvers(routeProgress))
            tripProgressView?.render(tripProgressApi.getTripProgress(routeProgress))
        }
    }

    private val offRouteObserver = OffRouteObserver { offRoute ->
        // REROUTE PREVENTION:
        // We intentionally do NOT call requestRoutes() here.
        // Backend is the single source of truth; going off-route should be handled by backend logic.
        if (offRoute) {
            // Optional: you can surface a UI message back to Flutter via another channel.
        }
    }

    private val mapboxNavigation: MapboxNavigation?
        get() = MapboxNavigationApp.current()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setTheme(androidx.appcompat.R.style.Theme_AppCompat_NoActionBar)
        setContentView(R.layout.activity_mapbox_navigation)

        mapView = findViewById(R.id.mapView)

        // Hide the zoom/scale meter indicator.
        mapView.scalebar.updateSettings {
            enabled = false
        }
        maneuverView = findViewById(R.id.maneuverView)
        tripProgressView = findViewById(R.id.tripProgressView)
        startDrivingButton = findViewById(R.id.startDrivingButton)
        routeLoadingIndicator = findViewById(R.id.routeLoadingIndicator)

        // Preview mode by default: show route overview + Start Driving.
        maneuverView?.visibility = View.GONE
        tripProgressView?.visibility = View.GONE
        startDrivingButton.visibility = View.GONE
        routeLoadingIndicator.visibility = View.VISIBLE
        startDrivingButton.setOnClickListener {
            if (tripStarted) return@setOnClickListener
            tripStarted = true

            startDrivingButton.visibility = View.GONE
            // We draw the backend-approved route geometry directly.
            // Since we are not using a Mapbox Directions-generated route here,
            // maneuvers/progress would be misleading.
            maneuverView?.visibility = View.GONE
            tripProgressView?.visibility = View.GONE

            Toast.makeText(this, "Backend-approved route active. Follow the blue line.", Toast.LENGTH_SHORT).show()

            mapboxNavigation?.startTripSession()
            navigationCamera.requestNavigationCameraToFollowing()
        }

        // Map initialization (basic camera); the camera will be controlled by NavigationCamera.
        mapView.mapboxMap.setCamera(
            CameraOptions.Builder()
                .zoom(14.0)
                .build()
        )

        // Ensure we have a style loaded; otherwise MapView can appear as a solid background.
        // Once loaded, draw the backend-approved route geometry directly.
        mapView.mapboxMap.loadStyleUri(Style.MAPBOX_STREETS) { style ->
            showBackendRoutePreview(style)
        }

        // Location puck driven by NavigationLocationProvider.
        mapView.location.apply {
            setLocationProvider(navigationLocationProvider)
            // Use default assets to avoid missing bearing icon warnings.
            locationPuck = createDefault2DPuck()
            enabled = true
        }

        viewportDataSource = MapboxNavigationViewportDataSource(mapView.mapboxMap)
        navigationCamera = NavigationCamera(mapView.mapboxMap, mapView.camera, viewportDataSource)

        routeLineApi = MapboxRouteLineApi(MapboxRouteLineApiOptions.Builder().build())
        routeLineView = MapboxRouteLineView(MapboxRouteLineViewOptions.Builder(this).build())

        val token = getString(R.string.mapbox_access_token)
        MapboxOptions.accessToken = token
        if (!MapboxNavigationApp.isSetup()) {
            MapboxNavigationApp.setup(
                NavigationOptions.Builder(this)
                    .build()
            )
        }
        MapboxNavigationApp.attach(this)

        mapboxNavigation?.setRerouteEnabled(false)

        // We intentionally do NOT call requestRoutes() here.
        // The preview route line is the backend-approved geometry.
    }

    private fun maybeRequestPreviewRoutes() {
        // No-op: we don't request routes from Mapbox Directions.
    }

    override fun onStart() {
        super.onStart()
        mapView.onStart()

        mapboxNavigation?.registerRoutesObserver(routesObserver)
        mapboxNavigation?.registerLocationObserver(locationObserver)
        mapboxNavigation?.registerRouteProgressObserver(routeProgressObserver)
        mapboxNavigation?.registerOffRouteObserver(offRouteObserver)

        maybeRequestPreviewRoutes()
    }

    override fun onStop() {
        super.onStop()
        mapboxNavigation?.unregisterRoutesObserver(routesObserver)
        mapboxNavigation?.unregisterLocationObserver(locationObserver)
        mapboxNavigation?.unregisterRouteProgressObserver(routeProgressObserver)
        mapboxNavigation?.unregisterOffRouteObserver(offRouteObserver)

        mapView.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
        maneuverApi.cancel()
    }
}
