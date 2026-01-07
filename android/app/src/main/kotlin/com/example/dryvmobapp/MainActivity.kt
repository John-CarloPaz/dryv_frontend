package com.example.dryvmobapp

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "dryv/platform"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
					else -> result.notImplemented()
				}
			}
	}
}
