import Flutter
import UIKit
import UserNotifications
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documentExport: DocumentExport?
  private var authentication: NativeAuthentication?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let authRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MyOccasioAuthentication") {
      let authChannel = FlutterMethodChannel(name: "ca.occasiotech.myoccasio/authentication", binaryMessenger: authRegistrar.messenger())
      authChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(FlutterError(code: "interrupted", message: "Sign-in was interrupted.", details: nil)); return }
        if call.method == "cancel" {
          self.authentication?.cancel()
          result(nil)
          return
        }
        guard call.method == "authenticate" else { result(FlutterMethodNotImplemented); return }
        guard self.authentication == nil else { result(FlutterError(code: "busy", message: "Sign-in is already open.", details: nil)); return }
        guard let args = call.arguments as? [String: Any], let value = args["url"] as? String,
              value.count <= 2048, let url = URL(string: value),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host?.isEmpty == false,
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              parts.path.hasSuffix("/auth/native"), let query = parts.queryItems,
              query.count == 1, query[0].name == "request",
              query[0].value?.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else {
          result(FlutterError(code: "invalid_url", message: "Invalid sign-in address.", details: nil)); return
        }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        guard let anchor = windows.first(where: { $0.isKeyWindow }) else {
          result(FlutterError(code: "unavailable", message: "No active window.", details: nil)); return
        }
        let operation = NativeAuthentication(anchor: anchor) { [weak self] outcome in
          self?.authentication = nil
          result(outcome)
        }
        self.authentication = operation
        operation.start(url)
      }
    }
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MyOccasioDocuments") else { return }
    let channel = FlutterMethodChannel(name: "ca.occasiotech.myoccasio/documents", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result(false); return }
      guard self.documentExport == nil else {
        result(FlutterError(code: "busy", message: "A file export is already open.", details: nil)); return
      }
      guard let args = call.arguments as? [String: Any],
            let data = args["bytes"] as? FlutterStandardTypedData,
            let name = args["name"] as? String,
            !name.isEmpty, !data.data.isEmpty, data.data.count <= 4 * 1024 * 1024 else {
        result(FlutterError(code: "invalid_file", message: "Invalid document.", details: nil)); return
      }
      let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
      guard var presenter = windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "export_unavailable", message: "No active window.", details: nil)); return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      let operation = DocumentExport { [weak self] outcome in
        self?.documentExport = nil
        result(outcome)
      }
      self.documentExport = operation
      operation.start(name: name, data: data.data, presenter: presenter)
    }
  }
}

/// The operating system owns credentials and provider cookies. The app receives
/// a short-lived code, then validates state and exchanges it using PKCE in Dart.
private final class NativeAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
  private let anchor: UIWindow
  private var session: ASWebAuthenticationSession?
  private var completion: ((Any?) -> Void)?
  init(anchor: UIWindow, completion: @escaping (Any?) -> Void) {
    self.anchor = anchor
    self.completion = completion
  }
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
  func start(_ url: URL) {
    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "ca.occasiotech.myoccasio.auth") { [weak self] callback, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
          self.finish(FlutterError(code: "cancelled", message: "Sign-in was cancelled.", details: nil))
        } else if error != nil || callback == nil {
          self.finish(FlutterError(code: "unavailable", message: "Sign-in did not finish.", details: nil))
        } else {
          self.finish(callback!.absoluteString)
        }
      }
    }
    self.session = session
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = true
    if !session.start() { finish(FlutterError(code: "unavailable", message: "Could not open sign-in.", details: nil)) }
  }
  func cancel() {
    session?.cancel()
    finish(FlutterError(code: "cancelled", message: "Sign-in was cancelled.", details: nil))
  }
  private func finish(_ outcome: Any?) {
    let callback = completion
    completion = nil
    session = nil
    callback?(outcome)
  }
}

/// Only a temporary protected copy is created; the system controls its destination.
private class DocumentExport: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private var directory: URL?
  private var completion: ((Any) -> Void)?

  init(completion: @escaping (Any) -> Void) { self.completion = completion }

  func start(name: String, data: Data, presenter: UIViewController) {
    do {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("myoccasio-export-" + UUID().uuidString, isDirectory: true)
      directory = folder
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let safeName = name.components(separatedBy: CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\"))).joined(separator: "_")
      let url = folder.appendingPathComponent(safeName == "." || safeName == ".." ? "resume.pdf" : safeName)
      try data.write(to: url, options: [.atomic, .completeFileProtection])
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      } else {
        picker = UIDocumentPickerViewController(url: url, in: .exportToService)
      }
      picker.delegate = self
      picker.presentationController?.delegate = self
      presenter.present(picker, animated: !UIAccessibility.isReduceMotionEnabled) {
        picker.presentationController?.delegate = self
      }
    } catch {
      finish(FlutterError(code: "export_failed", message: "Could not prepare document.", details: nil))
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(!urls.isEmpty) }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(false) }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish(false) }

  private func finish(_ outcome: Any) {
    guard let callback = completion else { return }
    completion = nil
    if let folder = directory { try? FileManager.default.removeItem(at: folder) }
    callback(outcome)
  }
}
