package com.example.smart_travel_planner

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_travel/maps").setMethodCallHandler { call, result ->
            if (call.method == "configured") {
                val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                result.success(!info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrBlank())
            } else result.notImplemented()
        }
    }
}
