package com.biohealthcare.bmh_app

// ─────────────────────────────────────────────────────────
//  QINGNIU SCALE BRIDGE — ANDROID
//
//  Copy to:
//    android/app/src/main/kotlin/com/biohealthcare/bmh_app/QnScalePlugin.kt
//
//  Requires in android/app/build.gradle.kts:
//    implementation("com.github.YolandaQingniu:qnscalesdkX:2.28.1")
//  and JitPack in android/build.gradle.kts allprojects.repositories.
//
//  The config file lives at:
//    android/app/src/main/assets/123456789.qn
//
//  Everything here fails soft. A scale that misbehaves reports an
//  error event; it never throws across the channel, because an
//  exception on this side becomes a crash on the Dart side.
// ─────────────────────────────────────────────────────────

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.qingniu.qnble.utils.QNLogUtils
import com.yolanda.health.qnblesdk.constant.CheckStatus
import com.yolanda.health.qnblesdk.constant.QNIndicator
import com.yolanda.health.qnblesdk.constant.UserGoal
import com.yolanda.health.qnblesdk.constant.UserShape
import com.yolanda.health.qnblesdk.listener.QNBleConnectionChangeListener
import com.yolanda.health.qnblesdk.listener.QNBleDeviceDiscoveryListener
import com.yolanda.health.qnblesdk.listener.QNResultCallback
import com.yolanda.health.qnblesdk.listener.QNScaleDataListener
import com.yolanda.health.qnblesdk.out.QNBleApi
import com.yolanda.health.qnblesdk.out.QNBleDevice
import com.yolanda.health.qnblesdk.out.QNScaleData
import com.yolanda.health.qnblesdk.out.QNScaleStoreData
import com.yolanda.health.qnblesdk.out.QNUser
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class QnScalePlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "bmh/qn_scale"
        const val EVENT_CHANNEL = "bmh/qn_scale_events"
    }

    private var api: QNBleApi? = null
    private var sink: EventChannel.EventSink? = null
    private var currentDevice: QNBleDevice? = null
    private val main = Handler(Looper.getMainLooper())

    // Event sinks must be touched on the main thread; SDK callbacks
    // do not guarantee which thread they arrive on.
    private fun send(payload: Map<String, Any?>) {
        main.post { sink?.success(payload) }
    }

    private fun sendError(message: String) {
        send(mapOf("event" to "error", "message" to message))
    }

    // ── EVENT CHANNEL ───────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ── METHOD CHANNEL ──────────────────────────────────
    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "init" -> initSdk(call, result)
            "startScan" -> startScan(result)
            "stopScan" -> stopScan(result)
            "connect" -> connect(call, result)
            "disconnect" -> disconnect(result)
            else -> result.notImplemented()
        }
    }

    private fun initSdk(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        try {
            val appId = call.argument<String>("appId") ?: "123456789"
            val config = call.argument<String>("configAndroid")
                ?: "file:///android_asset/123456789.qn"

            QNLogUtils.setLogEnable(true)
            api = QNBleApi.getInstance(context)
            api?.initSdk(appId, config, object : QNResultCallback {
                override fun onResult(code: Int, msg: String?) {
                    if (code == CheckStatus.OK.code) {
                        result.success(true)
                    } else {
                        // Reported rather than thrown: an unusable SDK
                        // should leave the app running with the scale
                        // unavailable, not kill it.
                        sendError("SDK init failed ($code): $msg")
                        result.success(false)
                    }
                }
            })
        } catch (e: Throwable) {
            sendError("SDK init threw: ${e.message}")
            result.success(false)
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        val a = api
        if (a == null) {
            result.success(false); return
        }
        a.setBleDeviceDiscoveryListener(object : QNBleDeviceDiscoveryListener {
            override fun onDeviceDiscover(device: QNBleDevice?) {
                device ?: return
                send(mapOf(
                    "event" to "device",
                    "mac" to device.mac,
                    "name" to device.name,
                    "rssi" to device.rssi,
                    "modelId" to device.modeId))
            }

            override fun onStartScan() {}
            override fun onStopScan() {}
            override fun onScanFail(code: Int) {
                sendError("Scan failed ($code)")
            }
        })
        a.startBleDeviceDiscovery(object : QNResultCallback {
            override fun onResult(code: Int, msg: String?) {
                if (code != CheckStatus.OK.code) sendError("Scan: $msg")
            }
        })
        result.success(true)
    }

    private fun stopScan(result: MethodChannel.Result) {
        api?.stopBleDeviceDiscovery(object : QNResultCallback {
            override fun onResult(code: Int, msg: String?) {}
        })
        result.success(true)
    }

    private fun connect(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        val a = api
        val mac = call.argument<String>("mac")
        if (a == null || mac.isNullOrEmpty()) {
            result.success(false); return
        }

        val userId = call.argument<String>("userId") ?: "bmh_local_user"
        val gender = call.argument<String>("gender") ?: "male"
        val heightCm = call.argument<Int>("height") ?: 170
        val birthdayStr = call.argument<String>("birthday") ?: "1990-01-01"

        val birthday: Date = try {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(birthdayStr)
                ?: defaultBirthday()
        } catch (e: Exception) {
            defaultBirthday()
        }

        val user: QNUser = a.buildUser(
            userId, heightCm, gender, birthday,
            UserShape.SHAPE_NONE, UserGoal.GOAL_NONE, 1.0,
            object : QNResultCallback {
                override fun onResult(code: Int, msg: String?) {
                    if (code != CheckStatus.OK.code) sendError("User: $msg")
                }
            })

        val device = currentDevice
            ?: a.buildDevice(mac, "BioScale", "", object : QNResultCallback {
                override fun onResult(code: Int, msg: String?) {}
            })

        if (device == null) {
            sendError("Could not build a device for $mac")
            result.success(false); return
        }
        currentDevice = device

        a.setBleConnectionChangeListener(object : QNBleConnectionChangeListener {
            override fun onConnecting(device: QNBleDevice?) =
                send(mapOf("event" to "connection", "state" to "connecting"))

            override fun onConnected(device: QNBleDevice?) =
                send(mapOf("event" to "connection", "state" to "connected"))

            override fun onDisconnecting(device: QNBleDevice?) {}

            override fun onDisconnected(device: QNBleDevice?) =
                send(mapOf("event" to "connection", "state" to "disconnected"))

            override fun onConnectError(device: QNBleDevice?, code: Int) {
                sendError("Connection error ($code)")
            }

            override fun onServiceSearchComplete(device: QNBleDevice?) {}
        })

        a.setDataListener(object : QNScaleDataListener {
            // Live weight while the person is still settling. Streamed
            // for the animation only — never stored, because a moving
            // reading is not a measurement.
            override fun onGetUnsteadyWeight(device: QNBleDevice?, weight: Double) {
                send(mapOf("event" to "weighing", "weight" to weight))
            }

            override fun onGetScaleData(device: QNBleDevice?, data: QNScaleData?) {
                data ?: return
                val items = mutableListOf<Map<String, Any?>>()
                data.allItem?.forEach { item ->
                    items.add(mapOf(
                        "type" to item.type,
                        "name" to item.name,
                        "value" to item.value,
                        "valueType" to item.valueType))
                }
                send(mapOf(
                    "event" to "measurement",
                    "weight" to data.getItemValue(QNIndicator.TYPE_WEIGHT),
                    "measureTime" to data.measureTime?.time,
                    "hmac" to data.hmac,
                    "items" to items))
            }

            override fun onGetStoredScale(
                device: QNBleDevice?,
                storedDataList: MutableList<QNScaleStoreData>?
            ) {}

            override fun onGetElectric(
                device: QNBleDevice?, electric: Int
            ) {}

            override fun onScaleStateChange(device: QNBleDevice?, status: Int) {}

            override fun onScaleEventChange(device: QNBleDevice?, event: Int) {}
        })

        a.connectDevice(device, user, object : QNResultCallback {
            override fun onResult(code: Int, msg: String?) {
                if (code != CheckStatus.OK.code) sendError("Connect: $msg")
            }
        })
        result.success(true)
    }

    private fun disconnect(result: MethodChannel.Result) {
        val d = currentDevice
        if (api != null && d != null) {
            api?.disconnectDevice(d, object : QNResultCallback {
                override fun onResult(code: Int, msg: String?) {}
            })
        }
        currentDevice = null
        result.success(true)
    }

    private fun defaultBirthday(): Date {
        val c = Calendar.getInstance()
        c.set(1990, 0, 1)
        return c.time
    }
}
