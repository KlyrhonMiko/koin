package com.example.koin

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
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
