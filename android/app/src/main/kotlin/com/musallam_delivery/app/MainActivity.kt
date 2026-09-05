package com.musallam_delivery.app

import android.app.Activity
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
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
        private const val DEVICE_PROFILE_CHANNEL = "dpd_userapp/device_profile"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_PROFILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(readDeviceProfile())
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

    /// Battery health and SoC are not exposed by device_info_plus / battery_plus.
    /// The battery broadcast is sticky, so registerReceiver(null, ...) returns the
    /// last value without subscribing.
    private fun readDeviceProfile(): Map<String, Any?> {
        val battery = try {
            registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (_: Exception) {
            null
        }
        val healthRaw = battery?.getIntExtra(
            BatteryManager.EXTRA_HEALTH,
            BatteryManager.BATTERY_HEALTH_UNKNOWN
        ) ?: BatteryManager.BATTERY_HEALTH_UNKNOWN
        val health = when (healthRaw) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
            BatteryManager.BATTERY_HEALTH_COLD -> "cold"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
            else -> "unknown"
        }
        val tempTenths = battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val tempC = if (tempTenths == null || tempTenths == Int.MIN_VALUE) null else tempTenths / 10.0
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val pct = if (level >= 0 && scale > 0) (level * 100) / scale else null

        val socModel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else null
        val socManufacturer =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MANUFACTURER else null

        return mapOf(
            "battery_health" to health,
            "battery_temp_c" to tempC,
            "battery_pct" to pct,
            "soc_model" to socModel,
            "soc_manufacturer" to socManufacturer,
            "hardware" to Build.HARDWARE,
            "board" to Build.BOARD,
            "cpu_cores" to Runtime.getRuntime().availableProcessors(),
        )
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
