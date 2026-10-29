import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CutLinkGlass") else { return }
    registrar.register(CutLinkGlassFactory(), withId: "cutlink/glass-surface")
    let channel = FlutterMethodChannel(name: "cutlink/glass", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "available" { result(true) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
}

/// Kept in this tracked target file so no Xcode project file edits are needed.
final class CutLinkGlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    CutLinkGlassView(frame: frame, dark: (args as? [String: Any])?["dark"] as? Bool ?? false)
  }
}

final class CutLinkGlassView: NSObject, FlutterPlatformView {
  private let effectView: UIVisualEffectView
  init(frame: CGRect, dark: Bool) {
    let effect: UIVisualEffect
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      effect = glass
    } else {
      effect = UIBlurEffect(style: .systemMaterial)
    }
    #else
    effect = UIBlurEffect(style: .systemMaterial)
    #endif
    effectView = UIVisualEffectView(effect: effect)
    super.init()
    effectView.frame = frame
    effectView.overrideUserInterfaceStyle = dark ? .dark : .light
    effectView.layer.cornerRadius = 38
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    effectView.isUserInteractionEnabled = false
    effectView.isAccessibilityElement = false
  }
  func view() -> UIView { effectView }
}
