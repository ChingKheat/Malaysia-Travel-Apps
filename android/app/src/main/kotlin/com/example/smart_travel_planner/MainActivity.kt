package com.example.smart_travel_planner

import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var headingStream: HeadingStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_travel/maps").setMethodCallHandler { call, result ->
            if (call.method == "configured") {
                val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                result.success(!info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrBlank())
            } else result.notImplemented()
        }
        val stream = HeadingStream(this)
        headingStream = stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_travel/heading")
            .setStreamHandler(stream)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        headingStream?.onCancel(null)
        headingStream = null
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_travel/heading")
            .setStreamHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

private class HeadingStream(private val activity: MainActivity) :
    EventChannel.StreamHandler, SensorEventListener {
    private val sensors = activity.getSystemService(SensorManager::class.java)
    private val rotationMatrix = FloatArray(9)
    private val screenMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors?.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null ||
            sensors?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI) != true
        ) {
            events.endOfStream()
            return
        }
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sensors?.unregisterListener(this)
        sink = null
    }

    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        val (xAxis, yAxis) = when (activity.windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        if (!SensorManager.remapCoordinateSystem(rotationMatrix, xAxis, yAxis, screenMatrix)) return

        SensorManager.getOrientation(screenMatrix, orientation)
        val degrees = Math.toDegrees(orientation[0].toDouble())
        if (degrees.isFinite()) sink?.success((degrees + 360.0) % 360.0)
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) = Unit
}
