import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
      let values = UserDefaults.standard.array(forKey: self.captureKey) ?? []
      UserDefaults.standard.set([], forKey: self.captureKey)
      result(values)
    }
  }
}
