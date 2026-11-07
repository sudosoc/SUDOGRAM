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
                } else if (call.method == "saveFile") {
                    val src = call.argument<String>("src") ?: ""
                    val dir = call.argument<String>("dir") ?: "Files"
                    val name = call.argument<String>("name") ?: "file"
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    Thread {
                        try {
                            val out = saveToDownloads(src, dir, name, mime)
                            runOnUiThread { result.success(out) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("save", e.toString(), null) }
                        }
                    }.start()
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

    private fun saveToDownloads(src: String, dir: String, name: String, mime: String): String {
        val rel = "Download/SUDOGRAM/$dir"
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mime)
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, rel)
            }
            val uri = contentResolver.insert(
                android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
            ) ?: throw Exception("insert failed")
            contentResolver.openOutputStream(uri)!!.use { o ->
                java.io.File(src).inputStream().use { it.copyTo(o) }
            }
            return "$rel/$name"
        }
        val d = java.io.File(
            android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS),
            "SUDOGRAM/$dir"
        )
        d.mkdirs()
        val f = java.io.File(d, name)
        java.io.File(src).copyTo(f, true)
        return f.absolutePath
    }
}
