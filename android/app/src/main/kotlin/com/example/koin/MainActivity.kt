package com.example.koin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.content.res.Configuration
import android.graphics.drawable.ColorDrawable
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    private var backupFolderBridge: BackupFolderBridge? = null
    private var channel: MethodChannel? = null
    private var dartReady = false
    private var pendingQuickEntry = false
    private var windowThemeChannel: MethodChannel? = null
    private var windowBackgroundColor: Int? = null
    private var windowDark = false

    @Suppress("DEPRECATION")
    private fun applyWindowTheme() {
        val background = windowBackgroundColor ?: return
        window.setBackgroundDrawable(ColorDrawable(background))
        window.navigationBarColor = background
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = background
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        WindowCompat.getInsetsController(window, window.decorView)
            .isAppearanceLightNavigationBars = !windowDark
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyWindowTheme()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyWindowTheme()
    }

    override fun onResume() {
        super.onResume()
        applyWindowTheme()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        windowThemeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "koin/window_theme")
        windowThemeChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setTheme") {
                val background = call.argument<Number>("backgroundColor")
                val dark = call.argument<Boolean>("dark")
                if (background == null || dark == null) {
                    result.error("invalid_theme", "Window theme requires a background color and brightness", null)
                } else {
                    windowBackgroundColor = background.toInt()
                    windowDark = dark
                    applyWindowTheme()
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        backupFolderBridge = BackupFolderBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        pendingQuickEntry = pendingQuickEntry || intent?.action == QUICK_ENTRY_ACTION
        if (intent?.action == QUICK_ENTRY_ACTION) intent.action = Intent.ACTION_MAIN
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openQuickEntry" -> {
                    startActivity(Intent(this, QuickEntryActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    })
                    result.success(null)
                }
                "getLaunchAction" -> {
                    dartReady = true
                    val action = if (pendingQuickEntry) "addTransaction" else null
                    pendingQuickEntry = false
                    result.success(action)
                }
                "addTile" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val manager = getSystemService(StatusBarManager::class.java)
                        if (manager == null) {
                            result.success("unavailable")
                        } else {
                            try {
                                manager.requestAddTileService(
                                    ComponentName(this, AddTransactionTileService::class.java),
                                    getString(R.string.quick_transaction_tile_label),
                                    Icon.createWithResource(this, R.drawable.ic_add_transaction),
                                    mainExecutor
                                ) { code ->
                                    result.success(when (code) {
                                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
                                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "declined"
                                        else -> "unavailable"
                                    })
                                }
                            } catch (_: RuntimeException) {
                                result.success("unavailable")
                            }
                        }
                    } else {
                        result.success("unavailable")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == QUICK_ENTRY_ACTION) {
            intent.action = Intent.ACTION_MAIN
            if (dartReady) channel?.invokeMethod("addTransaction", null)
            else pendingQuickEntry = true
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupFolderBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        windowThemeChannel?.setMethodCallHandler(null)
        windowThemeChannel = null
        backupFolderBridge?.dispose()
        backupFolderBridge = null
        channel?.setMethodCallHandler(null)
        channel = null
        dartReady = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        const val CHANNEL = "koin/quick_transaction"
        const val QUICK_ENTRY_ACTION = "com.example.koin.ADD_TRANSACTION"
    }
}
