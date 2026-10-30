import Flutter
import UIKit

/// The one native thing the SDK needs on iOS: keeping the card screen out
/// of the app switcher. The window is covered while the app is inactive so
/// the multitasking snapshot shows nothing.
///
/// Screenshots are not blocked. The known way to do that, re-parenting the
/// window's layer under a secure UITextField, draws the screen clipped or
/// scaled on recent iOS and leaves it black after the app was backgrounded.
/// A card form the customer cannot read is worse than one they can
/// screenshot of their own card.
public class PesaCheckoutPlugin: NSObject, FlutterPlugin {
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
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.showCover()
    })
    for name in [UIApplication.didBecomeActiveNotification, UIApplication.willEnterForegroundNotification] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.hideCover()
      })
    }
  }

  private func disable() {
    hideCover()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
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
