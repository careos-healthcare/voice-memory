package com.voicememory.mobile

import android.content.Intent
import android.os.Bundle
import com.voicememory.mobile.widget.ObjectiveWidgetStorage
import com.voicememory.mobile.widget.TodayCheckWidgetProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "archive_me/current_objective_widget"
    private var pendingWidgetRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleWidgetMethod)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWidgetRoute(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetRoute(intent)
    }

    private fun captureWidgetRoute(intent: Intent?) {
        val route = intent?.getStringExtra(ObjectiveWidgetStorage.EXTRA_WIDGET_ROUTE)
        if (!route.isNullOrBlank()) {
            pendingWidgetRoute = route
        }
    }

    private fun handleWidgetMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCurrentObjectiveWidgetAvailable" -> result.success(true)
            "updateCurrentObjectiveWidget" -> {
                val payload = call.arguments as? Map<*, *>
                if (payload == null) {
                    result.error("invalid_args", "Expected payload map", null)
                    return
                }
                ObjectiveWidgetStorage.save(this, payload)
                TodayCheckWidgetProvider.requestUpdate(this)
                result.success(null)
            }
            "clearCurrentObjectiveWidget" -> {
                ObjectiveWidgetStorage.clear(this)
                TodayCheckWidgetProvider.requestUpdate(this)
                result.success(null)
            }
            "consumePendingWidgetRoute" -> {
                val route = pendingWidgetRoute?.trim().orEmpty()
                pendingWidgetRoute = null
                result.success(route)
            }
            else -> result.notImplemented()
        }
    }
}
