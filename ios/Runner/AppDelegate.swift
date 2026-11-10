import CoreLocation
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
      FlutterEventChannel(name: "smart_travel/heading", binaryMessenger: registrar.messenger())
        .setStreamHandler(HeadingStream())
    }
  }
}

private final class HeadingStream: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      events(FlutterEndOfEventStream)
      return nil
    }
    sink = events
    manager.delegate = self
    manager.headingFilter = 3
    manager.headingOrientation = screenOrientation
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    manager.delegate = nil
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    let orientation = screenOrientation
    if manager.headingOrientation != orientation {
      manager.headingOrientation = orientation
      return
    }
    guard heading.headingAccuracy >= 0 else {
      sink?(nil)
      return
    }
    let degrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
    sink?(degrees)
  }

  private var screenOrientation: CLDeviceOrientation {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.windows.contains(where: \.isKeyWindow) }
    switch scene?.interfaceOrientation {
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    case .portraitUpsideDown: return .portraitUpsideDown
    default: return .portrait
    }
  }
}
