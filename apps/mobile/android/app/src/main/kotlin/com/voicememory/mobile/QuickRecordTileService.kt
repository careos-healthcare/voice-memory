package com.voicememory.mobile

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/// Quick Settings tile that opens ArchiveMe and starts a recording.
///
/// Manifest declaration:
/// ```xml
/// <service
///     android:name=".QuickRecordTileService"
///     android:exported="true"
///     android:icon="@mipmap/ic_launcher"
///     android:label="Record"
///     android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
///     <intent-filter>
///         <action android:name="android.service.quicksettings.action.QS_TILE" />
///     </intent-filter>
/// </service>
/// ```
class QuickRecordTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            label = "Record"
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val launch = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.QUICK_ACTION_EXTRA, MainActivity.START_RECORDING)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pending = PendingIntent.getActivity(
            this,
            REQUEST_CODE,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(launch)
        }
    }

    private companion object {
        const val REQUEST_CODE = 18
    }
}
