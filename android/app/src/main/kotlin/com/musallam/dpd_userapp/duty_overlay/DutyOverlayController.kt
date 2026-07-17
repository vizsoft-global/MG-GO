package com.musallam.dpd_userapp.duty_overlay

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.musallam.dpd_userapp.MainActivity
import com.musallam.dpd_userapp.R
import kotlin.math.abs

object DutyOverlayController {
    private var enabled = false
    private var activityVisible = true
    private var windowManager: WindowManager? = null
    private var bubbleOverlay: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var gpsOverlay: View? = null
    private var appContext: Context? = null

    fun setContext(context: Context) {
        appContext = context.applicationContext
        windowManager =
            context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    fun setActivityVisible(visible: Boolean) {
        activityVisible = visible
        if (!enabled) return
        if (visible) {
            hideBubbleOverlay()
        } else {
            showBubbleOverlay()
        }
    }

    fun enable() {
        enabled = true
        updateGpsOverlay()
        if (!activityVisible) {
            showBubbleOverlay()
        }
    }

    fun disable() {
        enabled = false
        hideBubbleOverlay()
        hideGpsOverlay()
    }

    fun isEnabled(): Boolean = enabled

    fun hasOverlayPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun requestOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            )
            activity.startActivity(intent)
        }
    }

    private fun isLocationEnabled(): Boolean {
        val context = appContext ?: return true
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun updateGpsOverlay() {
        if (!enabled) return
        if (isLocationEnabled()) {
            hideGpsOverlay()
        } else {
            showGpsOverlay()
        }
    }

    private fun showBubbleOverlay() {
        if (!enabled || activityVisible) return
        if (bubbleOverlay != null) return
        val context = appContext ?: return
        if (!hasOverlayPermission(context)) return

        val view = LayoutInflater.from(context).inflate(R.layout.duty_floating_bubble, null)
        val params = bubbleLayoutParams(context)
        attachBubbleInteractions(view, params)

        try {
            windowManager?.addView(view, params)
            bubbleOverlay = view
            bubbleParams = params
        } catch (_: Throwable) {
            bubbleOverlay = null
            bubbleParams = null
        }
    }

    private fun hideBubbleOverlay() {
        val view = bubbleOverlay ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Throwable) {
        } finally {
            bubbleOverlay = null
            bubbleParams = null
        }
    }

    private fun attachBubbleInteractions(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var dragging = false

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    dragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (!dragging && (abs(dx) > 8 || abs(dy) > 8)) {
                        dragging = true
                    }
                    if (dragging) {
                        params.x = initialX + (initialTouchX - event.rawX).toInt()
                        params.y = initialY - dy
                        windowManager?.updateViewLayout(v, params)
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!dragging) {
                        bringAppToFront()
                    }
                    true
                }

                else -> false
            }
        }
    }

    private fun showGpsOverlay() {
        if (!enabled) return
        if (gpsOverlay != null) return
        val context = appContext ?: return
        if (!hasOverlayPermission(context)) return

        val view = LayoutInflater.from(context).inflate(R.layout.duty_gps_lock_overlay, null)
        view.findViewById<Button>(R.id.open_gps_button)?.setOnClickListener {
            context.startActivity(
                Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK,
                ),
            )
        }
        view.findViewById<TextView>(R.id.gps_lock_message)?.text =
            context.getString(R.string.duty_gps_lock_message)

        val params = gpsOverlayLayoutParams()
        try {
            windowManager?.addView(view, params)
            gpsOverlay = view
        } catch (_: Throwable) {
            gpsOverlay = null
        }
    }

    private fun hideGpsOverlay() {
        val view = gpsOverlay ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Throwable) {
        } finally {
            gpsOverlay = null
        }
    }

    private fun bubbleLayoutParams(context: Context): WindowManager.LayoutParams {
        val margin = dp(context, 16)
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = margin
            y = margin
        }
    }

    private fun gpsOverlayLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }
    }

    private fun overlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun dp(context: Context, value: Int): Int {
        return (value * context.resources.displayMetrics.density).toInt()
    }

    private fun bringAppToFront() {
        val context = appContext ?: return
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }
        context.startActivity(intent)
    }

    fun onLocationStateChanged() {
        updateGpsOverlay()
    }

    fun tick() {
        if (!enabled) return
        updateGpsOverlay()
        if (!activityVisible) {
            showBubbleOverlay()
        }
    }
}
