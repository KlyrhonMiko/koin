package com.example.koin

import android.content.res.Configuration
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.view.WindowInsets
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** A separate, temporary task; the full app opens only on an explicit user action. */
class QuickEntryActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var contentHeightDp = 280.0

    override fun getDartEntrypointFunctionName() = "quickEntry"
    override fun getBackgroundMode() = BackgroundMode.transparent
    override fun getRenderMode() = RenderMode.texture
    override fun getTransparencyMode() = TransparencyMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        contentHeightDp = savedInstanceState?.getDouble("contentHeightDp", 280.0) ?: 280.0
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        resizeWindow()
    }

    private fun resizeWindow() {
        val metrics = resources.displayMetrics
        window.setGravity(Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL)
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT,
            (contentHeightDp * metrics.density).toInt().coerceIn(
                (180 * metrics.density).toInt(), (metrics.heightPixels * 0.9).toInt()))
        window.attributes = window.attributes.apply {
            dimAmount = 0.35f
            y = 0
            // Floating windows otherwise stop above the navigation bar, exposing
            // the launcher underneath even when navigationBarColor is set.
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                setFitInsetsTypes(WindowInsets.Type.statusBars() or
                    WindowInsets.Type.captionBar() or WindowInsets.Type.ime())
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        resizeWindow()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putDouble("contentHeightDp", contentHeightDp)
        super.onSaveInstanceState(outState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "koin/quick_window")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "resize" -> {
                    contentHeightDp = call.argument<Number>("height")?.toDouble() ?: 280.0
                    call.argument<Number>("backgroundColor")?.let {
                        window.navigationBarColor = it.toInt()
                    }
                    if (android.os.Build.VERSION.SDK_INT >= 29) {
                        window.isNavigationBarContrastEnforced = false
                    }
                    resizeWindow()
                    result.success(null)
                }
                "openApp" -> {
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent == null) {
                        result.error("unavailable", "Could not open Koin", null)
                    } else {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                        startActivity(launchIntent)
                        result.success(null)
                        finishAndRemoveTask()
                    }
                }
                "close" -> {
                    result.success(null)
                    finishAndRemoveTask()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
