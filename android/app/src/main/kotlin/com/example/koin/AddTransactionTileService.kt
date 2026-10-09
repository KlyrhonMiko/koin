package com.example.koin

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class AddTransactionTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            icon = Icon.createWithResource(this@AddTransactionTileService, R.drawable.ic_add_transaction)
            state = Tile.STATE_INACTIVE
            label = getString(R.string.quick_transaction_tile_label)
            contentDescription = getString(R.string.quick_transaction_tile_description)
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        // Require unlocking before showing financial data.
        if (isLocked) unlockAndRun { openTransaction() }
        else openTransaction()
    }

    @Suppress("DEPRECATION")
    private fun openTransaction() {
        val intent = Intent(this, QuickEntryActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // The tile can be tapped without any Koin activity being visible.
            // Android 15+ requires the creator to explicitly grant background
            // launch privileges; otherwise this only works soon after using Koin.
            val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                ActivityOptions.makeBasic().apply {
                    setPendingIntentCreatorBackgroundActivityStartMode(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
                            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS
                        } else {
                            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                        }
                    )
                }.toBundle()
            } else null
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                options
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
