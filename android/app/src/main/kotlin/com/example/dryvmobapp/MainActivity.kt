package com.example.dryvmobapp

import android.content.Intent
import android.location.LocationManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import com.example.dryvmobapp.navigation.BackendApprovedRouteStore
import com.example.dryvmobapp.navigation.MapboxNavigationActivity
import com.mapbox.geojson.Point

class MainActivity : FlutterActivity() {
	private val PLATFORM_CHANNEL = "dryv/platform"
	private val NAV_CHANNEL = "mapbox_navigation"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openLocationSettings" -> {
						try {
							val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
							result.success(null)
						} catch (e: Exception) {
							result.error("OPEN_LOCATION_SETTINGS_FAILED", e.message, null)
						}
					}
					"getLastKnownLocation" -> {
						try {
							val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
							val providers = locationManager.getProviders(true)
							var best = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
							for (p in providers) {
								val l = locationManager.getLastKnownLocation(p) ?: continue
								if (best == null || l.accuracy < best!!.accuracy) best = l
							}
							if (best == null) {
								result.success(null)
							} else {
								result.success(mapOf("lat" to best.latitude, "lng" to best.longitude))
							}
						} catch (e: Exception) {
							result.error("GET_LAST_KNOWN_LOCATION_FAILED", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAV_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"setApprovedRoute" -> {
						try {
							val args = call.arguments as? Map<*, *>
							if (args == null) {
								result.error("INVALID_ARGS", "Missing args", null)
								return@setMethodCallHandler
							}

							val coords = args["coordinates"] as? List<*>
							val waypointIndices = args["waypointIndices"] as? List<*>
							val directionsRouteJson = args["directionsRouteJson"] as? String

							if (coords == null || coords.size < 2) {
								result.error("INVALID_WAYPOINTS", "At least origin and destination are required", null)
								return@setMethodCallHandler
							}

							val points = coords.mapNotNull { item ->
								val m = item as? Map<*, *> ?: return@mapNotNull null
								val lat = (m["lat"] as? Number)?.toDouble() ?: return@mapNotNull null
								val lng = (m["lng"] as? Number)?.toDouble() ?: return@mapNotNull null
								Point.fromLngLat(lng, lat)
							}
							if (points.size < 2) {
								result.error("INVALID_WAYPOINTS", "Invalid coordinate list", null)
								return@setMethodCallHandler
							}

							val wpIdx = waypointIndices
								?.mapNotNull { (it as? Number)?.toInt() }
								?: listOf(0, points.size - 1)

							// SILENT WAYPOINT LOGIC:
							// Only origin and destination should be non-silent.
							// Intermediates are treated as silent by passing waypointIndices=[0,last].
							BackendApprovedRouteStore.set(
								directionsRouteJson = directionsRouteJson,
								coordinates = points,
								waypointIndices = wpIdx,
							)

							result.success(null)
						} catch (e: Exception) {
							result.error("SET_ROUTE_FAILED", e.message, null)
						}
					}
					"startNavigation" -> {
						if (!BackendApprovedRouteStore.isReady()) {
							result.error("NO_ROUTE", "No backend-approved route set", null)
							return@setMethodCallHandler
						}
						try {
							val intent = Intent(this, MapboxNavigationActivity::class.java)
							startActivity(intent)
							result.success(null)
						} catch (e: Exception) {
							result.error("START_NAV_FAILED", e.message, null)
						}
					}
					"clearRoute" -> {
						BackendApprovedRouteStore.clear()
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}
}
