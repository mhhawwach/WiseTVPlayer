package com.wiseapps.wisetv

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.wiseapps.wisetv/device"
    private val eventChannelName  = "com.wiseapps.wisetv/pip_events"

    private var pipEventSink: EventChannel.EventSink? = null

    // ── Per-tier renderer ─────────────────────────────────────────────────
    // Impeller stutters video playback on weak TV GPUs (e.g. the Realtek-based
    // TCL), so on the LOW tier we fall back to Skia by adding the engine flag
    // BEFORE the engine starts (the renderer can't be switched from Dart at
    // runtime). High/capable devices keep Impeller. The tier comes from the
    // user's saved choice (written by the Flutter side via shared_preferences),
    // falling back to native RAM-based auto-detection for "auto".
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = FlutterShellArgs.fromIntent(intent)
        if (isLowTier()) {
            args.add("--no-enable-impeller")
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTV"           -> result.success(isTelevision())
                    "isPipSupported" -> result.success(isPipSupported())
                    "isLowEndDevice" -> result.success(isLowEndDevice())
                    "enterPip" -> {
                        val w = call.argument<Int>("width")  ?: 16
                        val h = call.argument<Int>("height") ?: 9
                        result.success(enterPip(w, h))
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Event channel — PiP mode transitions ─────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    pipEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    pipEventSink = null
                }
            })
    }

    // Called when the activity enters or exits PiP (API 26+).
    // The API-26 single-arg override is called on all API levels that support PiP.
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        pipEventSink?.success(isInPictureInPictureMode)
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun isPipSupported(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        else false

    private fun enterPip(ratioW: Int, ratioH: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(ratioW, ratioH))
                .build()
            enterPictureInPictureMode(params)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isTelevision(): Boolean {
        val pm = packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
               pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
    }

    // Auto-detect a low-end device by total RAM (the strongest signal for the
    // GPU/low-memory-killer issues we hit). ≤ 2.5 GB or the system low-RAM flag
    // ⇒ low-end (e.g. the 2 GB TCL). Also surfaced to Dart via the channel.
    private fun isLowEndDevice(): Boolean {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            val totalGb = mi.totalMem / (1024.0 * 1024.0 * 1024.0)
            am.isLowRamDevice || totalGb <= 2.5
        } catch (e: Exception) {
            false
        }
    }

    // Effective tier for the renderer decision: explicit user override wins,
    // otherwise auto-detection. Reads the value the Flutter shared_preferences
    // plugin persists (keys are prefixed "flutter.").
    private fun isLowTier(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return when (prefs.getString("flutter.perf_mode", "auto")) {
            "low"  -> true
            "high" -> false
            else   -> isLowEndDevice()
        }
    }
}
