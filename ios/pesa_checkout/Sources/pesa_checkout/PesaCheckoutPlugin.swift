import Flutter
import UIKit

/// The one native thing the SDK needs on iOS: keeping the card screen out
/// of screenshots and screen recordings. iOS has no FLAG_SECURE; the
/// established way is a secure text field layered under the window's
/// content, which makes the system render the whole layer tree as blank in
/// captures. On top of that the window is covered while the app is in the
/// background so the app-switcher snapshot shows nothing.
public class PesaCheckoutPlugin: NSObject, FlutterPlugin {
  private var secureField: UITextField?
  private var cover: UIView?
  private var observers: [NSObjectProtocol] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pesa_checkout/secure", binaryMessenger: registrar.messenger())
    let instance = PesaCheckoutPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enable":
      enable()
      result(nil)
    case "disable":
      disable()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var window: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func enable() {
    guard secureField == nil, let window = window else { return }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    window.addSubview(field)
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(window.layer)
    secureField = field

    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.showCover()
    })
    observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.hideCover()
    })
  }

  private func disable() {
    hideCover()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    guard let field = secureField, let window = window else { return }
    field.layer.sublayers?.last?.sublayers?.removeAll { $0 == window.layer }
    window.layer.superlayer?.addSublayer(window.layer)
    field.layer.removeFromSuperlayer()
    field.removeFromSuperview()
    secureField = nil
  }

  private func showCover() {
    guard cover == nil, let window = window else { return }
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .systemBackground
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    cover = view
  }

  private func hideCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
