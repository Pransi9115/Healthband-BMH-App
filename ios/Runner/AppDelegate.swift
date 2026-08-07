import Flutter
import UIKit
import UserNotifications

// Copy to ios/Runner/AppDelegate.swift.

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets a medication reminder appear while the app is open.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The scale bridge, registered alongside every other plugin so the
    // timing is never in question.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QnScalePlugin") {
      QnScalePlugin.register(with: registrar.messenger())
    }
  }
}
