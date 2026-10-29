package com.example.koin

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Uses the device's existing credential; Koin never stores a PIN or password. */
class DevicePrivacyBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "koin/device_privacy")
    private val preferences = activity.getSharedPreferences("koin_privacy", Context.MODE_PRIVATE)
    private var pending: MethodChannel.Result? = null
    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "protected") {
            val enabled = preferences.getBoolean("protected", false)
            applyProtected(enabled)
            channel.invokeMethod("protectionChanged", enabled)
        }
    }

    init {
        applyProtected(preferences.getBoolean("protected", false))
        preferences.registerOnSharedPreferenceChangeListener(preferenceListener)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setProtected" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    applyProtected(enabled)
                    preferences.edit().putBoolean("protected", enabled).apply()
                    result.success(null)
                }
                "authenticate" -> authenticate(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun applyProtected(enabled: Boolean) {
        if (enabled) activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Suppress("DEPRECATION")
    private fun authenticate(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Device unlock is already open", null)
            return
        }
        val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguard.isDeviceSecure) {
            result.error("screen_lock_required", "Set a device PIN, pattern or password first", null)
            return
        }
        val intent = keyguard.createConfirmDeviceCredentialIntent("Unlock Koin", "Confirm your device screen lock")
        if (intent == null) {
            result.error("unavailable", "Device unlock is unavailable", null)
            return
        }
        pending = result
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (_: RuntimeException) {
            pending = null
            result.error("unavailable", "Could not open device unlock", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending
        pending = null
        result?.success(resultCode == Activity.RESULT_OK)
        return true
    }

    fun dispose() {
        preferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
        channel.setMethodCallHandler(null)
        pending?.error("cancelled", "Device unlock was closed", null)
        pending = null
    }

    companion object { const val REQUEST_CODE = 7615 }
}
