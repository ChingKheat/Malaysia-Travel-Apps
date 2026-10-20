import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
       !key.isEmpty, !key.contains("$(") {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MapsConfiguration") {
      FlutterMethodChannel(name: "smart_travel/maps", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
        if call.method == "configured" {
          let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String ?? ""
          result(!key.isEmpty && !key.contains("$("))
        } else { result(FlutterMethodNotImplemented) }
      }
    }
  }
}
