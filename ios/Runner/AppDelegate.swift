import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appGroup = "group.net.floosy.app"
  private let captureKey = "floosy_pending_captures"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let captureChannel = FlutterMethodChannel(
      name: "net.floosy.app/capture",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    captureChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "consumePendingSms" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result([])
        return
      }
      let sharedDefaults = UserDefaults(suiteName: self.appGroup)
      var values = sharedDefaults?.array(forKey: self.captureKey) ?? []

      // Import anything queued by builds that used the app-only defaults
      // container before captures moved to the shared App Group.
      let legacyValues = UserDefaults.standard.array(forKey: self.captureKey) ?? []
      values.append(contentsOf: legacyValues)

      sharedDefaults?.removeObject(forKey: self.captureKey)
      UserDefaults.standard.removeObject(forKey: self.captureKey)
      result(values)
    }
  }
}
