package com.example.footnoted.spike.render_bench

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Exposes `adb shell am start ... --es/--ez` extras to Dart so a benchmark run
// can be scripted from the host without rebuilding (see MEASURE.md).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "render_bench/launch")
            .setMethodCallHandler { call, result ->
                if (call.method == "args") result.success(extras(intent)) else result.notImplemented()
            }
    }

    private fun extras(intent: Intent?): Map<String, Any?> {
        val bundle = intent?.extras ?: return emptyMap()
        return bundle.keySet().associateWith { key ->
            when (val v = @Suppress("DEPRECATION") bundle.get(key)) {
                is String, is Boolean, is Int, is Long, is Double -> v
                else -> v?.toString()
            }
        }
    }
}
