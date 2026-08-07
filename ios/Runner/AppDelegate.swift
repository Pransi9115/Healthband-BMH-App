import Flutter
import UIKit
import UserNotifications

// Copy to ios/Runner/AppDelegate.swift, or merge the QnScalePlugin
// registration into your existing one.

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

    // The scale bridge registers here, alongside every other plugin.
    // Registering it in didFinishLaunchingWithOptions instead would
    // depend on the root view controller already being a
    // FlutterViewController — and when it is not, the optional cast
    // fails silently and the bridge is simply never wired, which
    // surfaces in Dart as MissingPluginException with no clue why.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QnScalePlugin") {
      QnScalePlugin.register(with: registrar.messenger())
    }
  }
}
