package com.sudosoc.sudogram

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth (biometric prompt).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sudogram/window")
            .setMethodCallHandler { call, result ->
                if (call.method == "secure") {
                    val on = call.argument<Boolean>("on") == true
                    runOnUiThread {
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else if (call.method == "setLauncher") {
                    val idx = call.argument<Int>("index") ?: 0
                    val pm = packageManager
                    for (i in (listOf(idx) + (0 until 50).filter { it != idx })) {
                        val cn = android.content.ComponentName(this, "com.sudosoc.sudogram.Alias%02d".format(i))
                        try {
                            pm.setComponentEnabledSetting(
                                cn,
                                if (i == idx) android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                else android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                android.content.pm.PackageManager.DONT_KILL_APP
                            )
                        } catch (e: Exception) {
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
