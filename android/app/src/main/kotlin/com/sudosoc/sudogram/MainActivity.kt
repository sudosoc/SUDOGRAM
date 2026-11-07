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
                } else if (call.method == "exitReasons") {
                    val out = ArrayList<Map<String, Any?>>()
                    if (android.os.Build.VERSION.SDK_INT >= 30) {
                        try {
                            val am = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                            for (r in am.getHistoricalProcessExitReasons(packageName, 0, 12)) {
                                out.add(mapOf(
                                    "time" to r.timestamp,
                                    "reason" to r.reason,
                                    "status" to r.status,
                                    "importance" to r.importance,
                                    "desc" to (r.description ?: ""),
                                ))
                            }
                        } catch (e: Throwable) {}
                    }
                    result.success(out)
                } else if (call.method == "openBatterySettings") {
                    try {
                        startActivity(android.content.Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                } else if (call.method == "encodeOpus") {
                    val src = call.argument<String>("src") ?: ""
                    val dst = call.argument<String>("dst") ?: ""
                    Thread {
                        try {
                            OpusOgg.encode(src, dst)
                            runOnUiThread { result.success(dst) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("opus", e.toString(), null) }
                        }
                    }.start()
                } else if (call.method == "videoMeta") {
                    val path = call.argument<String>("path") ?: ""
                    val dst = call.argument<String>("dst") ?: ""
                    Thread {
                        try {
                            val r = android.media.MediaMetadataRetriever()
                            r.setDataSource(path)
                            var w = (r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH) ?: "0").toInt()
                            var h = (r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT) ?: "0").toInt()
                            val rot = (r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: "0").toInt()
                            val ms = (r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION) ?: "0").toLong()
                            if (rot == 90 || rot == 270) { val x = w; w = h; h = x }
                            var tw = 0
                            var th = 0
                            val frame = r.getFrameAtTime(if (ms > 1500) 1000000L else 0L, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                            if (frame != null && dst.isNotEmpty()) {
                                val scale = 320f / Math.max(frame.width, frame.height)
                                val bmp = android.graphics.Bitmap.createScaledBitmap(frame, Math.max(1, (frame.width * scale).toInt()), Math.max(1, (frame.height * scale).toInt()), true)
                                java.io.FileOutputStream(dst).use { bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, it) }
                                tw = bmp.width
                                th = bmp.height
                            }
                            r.release()
                            val out = hashMapOf<String, Any>("w" to w, "h" to h, "ms" to ms, "tw" to tw, "th" to th)
                            runOnUiThread { result.success(out) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("meta", e.toString(), null) }
                        }
                    }.start()
                } else if (call.method == "tts") {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: "en"
                    val dst = call.argument<String>("dst") ?: ""
                    var engine: android.speech.tts.TextToSpeech? = null
                    var answered = false
                    fun fail(msg: String) {
                        if (answered) return
                        answered = true
                        runOnUiThread { result.error("tts", msg, null) }
                        try { engine?.shutdown() } catch (_: Exception) {}
                    }
                    engine = android.speech.tts.TextToSpeech(applicationContext) { status ->
                        val e = engine
                        if (status != android.speech.tts.TextToSpeech.SUCCESS || e == null) {
                            fail("init"); return@TextToSpeech
                        }
                        val r = e.setLanguage(java.util.Locale(lang))
                        if (r == android.speech.tts.TextToSpeech.LANG_MISSING_DATA ||
                            r == android.speech.tts.TextToSpeech.LANG_NOT_SUPPORTED) {
                            fail("lang"); return@TextToSpeech
                        }
                        e.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                            override fun onStart(id: String?) {}
                            override fun onDone(id: String?) {
                                if (answered) return
                                answered = true
                                runOnUiThread { result.success(dst) }
                                try { e.shutdown() } catch (_: Exception) {}
                            }
                            @Deprecated("Deprecated in Java")
                            override fun onError(id: String?) { fail("synth") }
                        })
                        val rc = e.synthesizeToFile(text, android.os.Bundle(), java.io.File(dst), "sg_fx")
                        if (rc != android.speech.tts.TextToSpeech.SUCCESS) fail("synth")
                    }
                } else if (call.method == "setLauncher") {
                    val idx = call.argument<Int>("index") ?: 0
                    val pm = packageManager
                    for (i in (listOf(idx) + (0 until 56).filter { it != idx })) {
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
