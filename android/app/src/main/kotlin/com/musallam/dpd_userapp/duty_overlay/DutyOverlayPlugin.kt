package com.musallam.dpd_userapp.duty_overlay

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DutyOverlayPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "dpd_userapp/duty_overlay")
        channel.setMethodCallHandler(this)
        DutyOverlayController.setContext(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity ?: run {
            result.error("no_activity", "Activity not available", null)
            return
        }

        when (call.method) {
            "hasOverlayPermission" -> {
                result.success(DutyOverlayController.hasOverlayPermission(context))
            }
            "requestOverlayPermission" -> {
                DutyOverlayController.requestOverlayPermission(context)
                result.success(true)
            }
            "enableLock" -> {
                DutyOverlayController.enable()
                result.success(true)
            }
            "disableLock" -> {
                DutyOverlayController.disable()
                result.success(true)
            }
            "isLocked" -> {
                result.success(DutyOverlayController.isEnabled())
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        DutyOverlayController.setContext(binding.activity.applicationContext)
        binding.activity.application.registerActivityLifecycleCallbacks(
            object : android.app.Application.ActivityLifecycleCallbacks {
                override fun onActivityResumed(activity: Activity) {
                    DutyOverlayController.setActivityVisible(true)
                }

                override fun onActivityPaused(activity: Activity) {
                    DutyOverlayController.setActivityVisible(false)
                }

                override fun onActivityCreated(
                    activity: Activity,
                    savedInstanceState: android.os.Bundle?,
                ) {}

                override fun onActivityStarted(activity: Activity) {}

                override fun onActivityStopped(activity: Activity) {}

                override fun onActivitySaveInstanceState(
                    activity: Activity,
                    outState: android.os.Bundle,
                ) {}

                override fun onActivityDestroyed(activity: Activity) {}
            },
        )
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
