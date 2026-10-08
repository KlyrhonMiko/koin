package com.example.koin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var dartReady = false
    private var pendingQuickEntry = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingQuickEntry = pendingQuickEntry || intent?.action == QUICK_ENTRY_ACTION
        if (intent?.action == QUICK_ENTRY_ACTION) intent.action = Intent.ACTION_MAIN
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
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
