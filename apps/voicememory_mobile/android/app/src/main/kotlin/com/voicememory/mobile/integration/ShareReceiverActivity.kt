package com.voicememory.mobile.integration

import android.app.Activity
import android.os.Bundle
import android.widget.Toast
import com.voicememory.mobile.R
import java.util.concurrent.Executors

/**
 * Lightweight share target that never boots Flutter or opens the main vault.
 *
 * Incoming streams are copied directly into the Keystore-encrypted native
 * inbox. The Flutter app drains that inbox on its next normal launch.
 */
class ShareReceiverActivity : Activity() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val source = intent
        executor.execute {
            val saved = runCatching {
                ShareHandoffStore.ingest(applicationContext, source)
            }.getOrNull() != null
            runOnUiThread {
                Toast.makeText(
                    this,
                    if (saved) R.string.share_saved_securely else R.string.share_save_failed,
                    Toast.LENGTH_SHORT,
                ).show()
                finishAndRemoveTask()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }
}
