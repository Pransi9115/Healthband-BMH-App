package com.biohealthcare.bmh_app

// ─────────────────────────────────────────────────────────
//  Copy to:
//    android/app/src/main/kotlin/com/biohealthcare/bmh_app/MainActivity.kt
//
//  If your existing MainActivity already has content, keep it and add
//  only the configureFlutterEngine body below.
// ─────────────────────────────────────────────────────────

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val plugin = QnScalePlugin(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            QnScalePlugin.METHOD_CHANNEL
        ).setMethodCallHandler(plugin)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            QnScalePlugin.EVENT_CHANNEL
        ).setStreamHandler(plugin)
    }
}
