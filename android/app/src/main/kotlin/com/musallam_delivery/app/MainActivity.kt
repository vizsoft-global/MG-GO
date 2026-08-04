package com.musallam_delivery.app

import android.app.Activity
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.musallam_delivery.app.duty_overlay.DutyOverlayPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val APP_LIFECYCLE_CHANNEL = "dpd_userapp/app_lifecycle"
        private const val SECURITY_CHANNEL = "dpd_userapp/security"
        private const val SECURITY_EVENTS_CHANNEL = "dpd_userapp/security_events"
    }

    private var secureEnabled: Boolean = false
    private var securityEventSink: EventChannel.EventSink? = null
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(DutyOverlayPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LIFECYCLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        result.success(moveTaskToBack(true))
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureEnabled" -> {
                        val enabled = call.arguments<Boolean>() ?: false
                        setSecureEnabled(enabled)
                        result.success(true)
                    }
                    "isDeveloperModeEnabled" -> {
                        result.success(isDeveloperModeEnabled())
                    }
                    "isMockLocationSettingEnabled" -> {
                        result.success(isMockLocationSettingEnabled())
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    securityEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    securityEventSink = null
                }
            })
    }

    override fun onResume() {
        super.onResume()
        if (secureEnabled) {
            applySecureFlag()
            registerScreenCaptureCallbackIfAvailable()
        }
    }

    override fun onPause() {
        unregisterScreenCaptureCallbackIfNeeded()
        super.onPause()
    }

    private fun setSecureEnabled(enabled: Boolean) {
        secureEnabled = enabled
        if (enabled) {
            applySecureFlag()
            registerScreenCaptureCallbackIfAvailable()
        } else {
            clearSecureFlag()
            unregisterScreenCaptureCallbackIfNeeded()
        }
    }

    private fun applySecureFlag() {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun clearSecureFlag() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun registerScreenCaptureCallbackIfAvailable() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        if (screenCaptureCallback != null) {
            return
        }
        try {
            val callback = Activity.ScreenCaptureCallback {
                securityEventSink?.success("screenshot_attempt")
            }
            registerScreenCaptureCallback(
                ContextCompat.getMainExecutor(this),
                callback
            )
            screenCaptureCallback = callback
        } catch (t: Throwable) {
            screenCaptureCallback = null
        }
    }

    private fun unregisterScreenCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        val callback = screenCaptureCallback ?: return
        try {
            unregisterScreenCaptureCallback(callback)
        } catch (_: Throwable) {
            // ignore – unregistering best-effort
        } finally {
            screenCaptureCallback = null
        }
    }

    private fun isDeveloperModeEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) == 1
        } catch (_: Exception) {
            false
        }
    }

    private fun isMockLocationSettingEnabled(): Boolean {
        return try {
            @Suppress("DEPRECATION")
            Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ALLOW_MOCK_LOCATION
            ) == "1"
        } catch (_: Exception) {
            false
        }
    }
}
