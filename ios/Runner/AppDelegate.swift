import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var securityEventSink: FlutterEventSink?
  private var sensitiveProtectionEnabled = false
  private var privacyOverlayWindow: UIWindow?
  private var screenshotObserver: NSObjectProtocol?
  private var capturedObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let securityChannel = FlutterMethodChannel(
      name: "dpd_userapp/security",
      binaryMessenger: messenger
    )
    securityChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate gone", details: nil))
        return
      }
      switch call.method {
      case "setSecureEnabled":
        // Android-only FLAG_SECURE; iOS uses sensitive protection instead.
        result(true)
      case "setSensitiveProtectionEnabled":
        let enabled = (call.arguments as? Bool) ?? false
        self.setSensitiveProtectionEnabled(enabled)
        result(true)
      case "isScreenCaptured":
        result(UIScreen.main.isCaptured)
      case "isDeveloperModeEnabled", "isMockLocationSettingEnabled":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventsChannel = FlutterEventChannel(
      name: "dpd_userapp/security_events",
      binaryMessenger: messenger
    )
    eventsChannel.setStreamHandler(SecurityEventsStreamHandler { [weak self] sink in
      self?.securityEventSink = sink
    })
  }

  private func setSensitiveProtectionEnabled(_ enabled: Bool) {
    sensitiveProtectionEnabled = enabled
    if enabled {
      registerSensitiveObservers()
      if UIScreen.main.isCaptured {
        securityEventSink?("screen_captured")
      }
    } else {
      unregisterSensitiveObservers()
      hidePrivacyOverlay()
    }
  }

  private func registerSensitiveObservers() {
    unregisterSensitiveObservers()

    screenshotObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self, self.sensitiveProtectionEnabled else { return }
      self.securityEventSink?("screenshot_attempt")
    }

    capturedObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self, self.sensitiveProtectionEnabled else { return }
      if UIScreen.main.isCaptured {
        self.securityEventSink?("screen_captured")
      } else {
        self.securityEventSink?("screen_capture_ended")
      }
    }
  }

  private func unregisterSensitiveObservers() {
    if let screenshotObserver {
      NotificationCenter.default.removeObserver(screenshotObserver)
      self.screenshotObserver = nil
    }
    if let capturedObserver {
      NotificationCenter.default.removeObserver(capturedObserver)
      self.capturedObserver = nil
    }
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if sensitiveProtectionEnabled {
      showPrivacyOverlay()
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    if privacyOverlayWindow != nil { return }
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first else { return }

    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.backgroundColor = .systemBackground
    let controller = UIViewController()
    controller.view.backgroundColor = .systemBackground
    let label = UILabel()
    label.text = "Content hidden"
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
    ])
    window.rootViewController = controller
    window.isHidden = false
    privacyOverlayWindow = window
  }

  private func hidePrivacyOverlay() {
    privacyOverlayWindow?.isHidden = true
    privacyOverlayWindow = nil
  }
}

private final class SecurityEventsStreamHandler: NSObject, FlutterStreamHandler {
  private let onListen: (FlutterEventSink?) -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void) {
    self.onListen = onListen
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onListen(nil)
    return nil
  }
}
