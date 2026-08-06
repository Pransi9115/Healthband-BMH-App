import Flutter
import UIKit
import QNSDK

// ─────────────────────────────────────────────────────────
//  QINGNIU SCALE BRIDGE — iOS
//
//  Copy to: ios/Runner/QnScalePlugin.swift
//  Add to the Runner target in Xcode.
//
//  `import QNSDK` works because the Podfile uses use_frameworks! and
//  the pod declares static_framework, so CocoaPods builds it as a
//  module. Without use_frameworks! this would instead need a bridging
//  header line: #import "QNBleApi.h"
//
//  Mirrors the Kotlin bridge exactly: same channel names, same event
//  shapes, so the Dart side does not care which platform it is on.
//
//  Fails soft throughout. A scale that will not connect sends an error
//  event; it never crashes the host app.
// ─────────────────────────────────────────────────────────

class QnScalePlugin: NSObject, FlutterStreamHandler {

    static let methodChannel = "bmh/qn_scale"
    static let eventChannel = "bmh/qn_scale_events"

    private var sink: FlutterEventSink?
    private var currentDevice: QNBleDevice?
    private var user: QNUser?

    // ── REGISTRATION ────────────────────────────────────
    // Held so the instance is not deallocated the moment register
    // returns — the channels keep only weak references to handlers.
    private static var shared: QnScalePlugin?

    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = QnScalePlugin()
        shared = instance

        let method = FlutterMethodChannel(
            name: methodChannel,
            binaryMessenger: messenger)
        method.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }

        let events = FlutterEventChannel(
            name: eventChannel,
            binaryMessenger: messenger)
        events.setStreamHandler(instance)
    }

    // ── EVENTS ──────────────────────────────────────────
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink)
        -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    private func send(_ payload: [String: Any?]) {
        DispatchQueue.main.async { [weak self] in
            self?.sink?(payload)
        }
    }

    private func sendError(_ message: String) {
        send(["event": "error", "message": message])
    }

    // ── METHODS ─────────────────────────────────────────
    private func handle(_ call: FlutterMethodCall,
                        result: @escaping FlutterResult) {
        switch call.method {
        case "init":       initSdk(call, result)
        case "startScan":  startScan(result)
        case "stopScan":   stopScan(result)
        case "connect":    connect(call, result)
        case "disconnect": disconnect(result)
        default:           result(FlutterMethodNotImplemented)
        }
    }

    private func initSdk(_ call: FlutterMethodCall,
                         _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let appId = args["appId"] as? String ?? "123456789"
        let resource = args["configIos"] as? String ?? "123456789"

        guard let path = Bundle.main.path(forResource: resource,
                                          ofType: "qn") else {
            // The usual cause is the .qn file not being ticked for the
            // Runner target in Xcode — it is in the folder but not in
            // the bundle.
            sendError("Config file \(resource).qn is not in the bundle.")
            result(false)
            return
        }

        QNBleApi.sharedBleApi().initSdk(appId, firstDataFile: path) {
            [weak self] error in
            if let error = error {
                self?.sendError("SDK init failed: \(error.localizedDescription)")
                result(false)
            } else {
                result(true)
            }
        }
    }

    private func startScan(_ result: @escaping FlutterResult) {
        QNBleApi.sharedBleApi().setBleDeviceDiscoveryListener(self)
        QNBleApi.sharedBleApi().startBleDeviceDiscovery { [weak self] error in
            if let error = error {
                self?.sendError("Scan failed: \(error.localizedDescription)")
            }
        }
        result(true)
    }

    private func stopScan(_ result: @escaping FlutterResult) {
        QNBleApi.sharedBleApi().stopBleDeviceDiscovery { _ in }
        result(true)
    }

    private func connect(_ call: FlutterMethodCall,
                         _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let mac = args["mac"] as? String, !mac.isEmpty else {
            result(false)
            return
        }

        let userId = args["userId"] as? String ?? "bmh_local_user"
        let gender = args["gender"] as? String ?? "male"
        let height = args["height"] as? Int ?? 170
        let birthdayStr = args["birthday"] as? String ?? "1990-01-01"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let birthday = formatter.date(from: birthdayStr) ?? Date()

        user = QNBleApi.sharedBleApi().buildUser(
            userId,
            height: height,
            gender: gender,
            birthday: birthday,
            athleteType: 0) { [weak self] error in
                if let error = error {
                    self?.sendError("User: \(error.localizedDescription)")
                }
            }

        let device = currentDevice ?? QNBleApi.sharedBleApi().buildDevice(
            withMac: mac, name: "BioScale", modeId: "") { _ in }
        guard let device = device, let user = user else {
            sendError("Could not build a device for \(mac)")
            result(false)
            return
        }
        currentDevice = device

        QNBleApi.sharedBleApi().setBleConnectionChangeListener(self)
        QNBleApi.sharedBleApi().setDataListener(self)

        QNBleApi.sharedBleApi().connectDevice(device, user: user) {
            [weak self] error in
            if let error = error {
                self?.sendError("Connect: \(error.localizedDescription)")
            }
        }
        result(true)
    }

    private func disconnect(_ result: @escaping FlutterResult) {
        if let d = currentDevice {
            QNBleApi.sharedBleApi().disconnectDevice(d) { _ in }
        }
        currentDevice = nil
        result(true)
    }
}

// ── SDK CALLBACKS ───────────────────────────────────────
extension QnScalePlugin: QNBleDeviceDiscoveryListener {
    func onDeviceDiscover(_ device: QNBleDevice) {
        send([
            "event": "device",
            "mac": device.mac,
            "name": device.name,
            "rssi": device.rssi,
            "modelId": device.modeId,
        ])
    }
}

extension QnScalePlugin: QNBleConnectionChangeListener {
    func onConnecting(_ device: QNBleDevice) {
        send(["event": "connection", "state": "connecting"])
    }

    func onConnected(_ device: QNBleDevice) {
        send(["event": "connection", "state": "connected"])
    }

    func onDisconnecting(_ device: QNBleDevice) {}

    func onDisconnected(_ device: QNBleDevice) {
        send(["event": "connection", "state": "disconnected"])
    }

    func onConnectError(_ device: QNBleDevice, error: Error) {
        sendError("Connection error: \(error.localizedDescription)")
    }

    func onServiceSearchComplete(_ device: QNBleDevice) {}
}

extension QnScalePlugin: QNScaleDataListener {
    // Live weight while the person is still settling — for the
    // animation only, never stored.
    func onGetUnsteadyWeight(_ device: QNBleDevice, weight: Double) {
        send(["event": "weighing", "weight": weight])
    }

    func onGetScaleData(_ device: QNBleDevice, data: QNScaleData) {
        var items: [[String: Any?]] = []
        for item in data.getAllItem() {
            items.append([
                "type": item.type,
                "name": item.name,
                "value": item.value,
                "valueType": item.valueType,
            ])
        }
        send([
            "event": "measurement",
            "weight": data.getItemValue(1),
            "measureTime": data.measureTime.timeIntervalSince1970 * 1000,
            "hmac": data.hmac,
            "items": items,
        ])
    }

    func onGetStoredScale(_ device: QNBleDevice,
                          storedDataList: [QNScaleStoreData]) {}

    func onGetElectric(_ electric: UInt, device: QNBleDevice) {}

    func onScaleStateChange(_ device: QNBleDevice, scaleState: QNScaleState) {}

    func onScaleEventChange(_ device: QNBleDevice, scaleEvent: QNScaleEvent) {}
}
