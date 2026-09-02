import Flutter
import UIKit

/// iOS implementation of `whatsapp_share_plus`.
///
/// iOS gives an app far less control over where a share lands than Android
/// does, so this implementation picks between three mechanisms depending on
/// what is being sent:
///
/// - **Text, with or without a recipient** goes through the `whatsapp://send`
///   URL scheme, which opens the app directly with the message pre-filled.
/// - **A single photo, video, or audio clip with no caption** goes through
///   `UIDocumentInteractionController` using WhatsApp's own uniform type
///   identifiers, which narrows the open-in menu to WhatsApp.
/// - **Everything else** — multiple files, documents, or a file with a caption
///   — goes through `UIActivityViewController`, the system share sheet.
///
/// No iOS API lets an app send an attachment straight to a named contact, so
/// `phone` only applies to the text path.
public class WhatsappSharePlusPlugin: NSObject, FlutterPlugin, UIDocumentInteractionControllerDelegate {

    /// Retained for the lifetime of the open-in menu.
    ///
    /// `UIDocumentInteractionController` is held weakly by UIKit; without a
    /// strong reference here the menu is deallocated before it appears.
    private var documentController: UIDocumentInteractionController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "whatsapp_share_plus",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(WhatsappSharePlusPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isInstalled":
            let target = Target(wireName: arguments(call)["target"] as? String)
            result(isInstalled(target))

        case "installedTargets":
            result(Target.allCases.filter(isInstalled).map(\.wireName))

        case "isStickerPackSupported":
            result(true)

        case "share":
            share(arguments(call), result: result)

        case "openChat":
            openChat(arguments(call), result: result)

        case "diagnose":
            result(diagnose())

        case "addStickerPack":
            addStickerPack(arguments(call), result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Sharing

    private func share(_ args: [String: Any], result: @escaping FlutterResult) {
        let target = Target(wireName: args["target"] as? String)
        let text = (args["text"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let phone = (args["phone"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let files = args["files"] as? [[String: Any]] ?? []
        let allowFallback = args["allowFallback"] as? Bool ?? true

        guard text != nil || !files.isEmpty else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "A share needs text, at least one file, or both.",
                    details: nil
                )
            )
            return
        }

        if files.isEmpty {
            shareText(text: text, phone: phone, target: target,
                      allowFallback: allowFallback, result: result)
            return
        }

        // For attachments the question is whether *any* WhatsApp app is present,
        // not whether the requested one was detected. iOS routes files through a
        // share sheet where the user picks the destination anyway, and Business
        // detection depends on a URL scheme WhatsApp does not formally document
        // — so insisting on an exact match would refuse shares that would have
        // worked. A wa.me link cannot carry an attachment, so unlike a text
        // share there is no link fallback either way.
        guard Target.allCases.contains(where: isInstalled) else {
            result(notInstalledError(target))
            return
        }

        ShareStager.pruneOldSessions()

        // The direct-to-WhatsApp path only works for one media file with no
        // caption: the open-in menu carries a file and nothing else.
        let canUseOpenInMenu = files.count == 1
            && text == nil
            && ShareStager.whatsAppUTI(
                for: files[0]["mimeType"] as? String ?? ""
            ) != nil

        do {
            let staged = try ShareStager.stage(files, useWhatsAppExtension: canUseOpenInMenu)
            if canUseOpenInMenu, let file = staged.first {
                presentOpenInMenu(file, args: args, target: target, result: result)
            } else {
                presentActivitySheet(staged, text: text, args: args, result: result)
            }
        } catch let error as ShareStagerError {
            result(FlutterError(code: error.code, message: error.message, details: nil))
        } catch {
            result(
                FlutterError(
                    code: "FILE_ERROR",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private func shareText(
        text: String?,
        phone: String?,
        target: Target,
        allowFallback: Bool,
        result: @escaping FlutterResult
    ) {
        if let url = target.sendURL(phone: phone, text: text),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { opened in
                if opened {
                    result(
                        self.successMap(
                            status: "opened",
                            target: target,
                            message: "Opened \(target.displayName)."
                        )
                    )
                } else {
                    result(
                        FlutterError(
                            code: "SHARE_FAILED",
                            message: "\(target.displayName) refused to open the message.",
                            details: nil
                        )
                    )
                }
            }
            return
        }

        guard allowFallback else {
            result(notInstalledError(target))
            return
        }

        // wa.me works whether or not the app is installed: it opens WhatsApp
        // when present and WhatsApp's web page otherwise.
        guard let fallback = Target.waMeURL(phone: phone, text: text) else {
            result(notInstalledError(target))
            return
        }

        UIApplication.shared.open(fallback, options: [:]) { opened in
            if opened {
                result(
                    self.successMap(
                        status: "fallback",
                        target: nil,
                        message: "Opened wa.me in the browser."
                    )
                )
            } else {
                result(self.notInstalledError(target))
            }
        }
    }

    private func openChat(_ args: [String: Any], result: @escaping FlutterResult) {
        shareText(
            text: (args["text"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            phone: (args["phone"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            target: Target(wireName: args["target"] as? String),
            allowFallback: args["allowFallback"] as? Bool ?? true,
            result: result
        )
    }

    /// Shows WhatsApp's own open-in menu for a single media file.
    private func presentOpenInMenu(
        _ file: StagedFile,
        args: [String: Any],
        target: Target,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.async {
            guard let host = UIApplication.topViewController() else {
                result(self.noViewControllerError())
                return
            }

            let controller = UIDocumentInteractionController(url: file.url)
            controller.uti = ShareStager.whatsAppUTI(for: file.mimeType)
            controller.delegate = self
            self.documentController = controller

            let anchor = self.anchorRect(from: args, in: host.view)
            let presented = controller.presentOpenInMenu(
                from: anchor,
                in: host.view,
                animated: true
            )

            if presented {
                result(
                    self.successMap(
                        status: "sheetPresented",
                        target: target,
                        message: "Presented WhatsApp's open-in menu."
                    )
                )
            } else {
                self.documentController = nil
                result(
                    FlutterError(
                        code: "SHARE_FAILED",
                        message: "No installed app accepts this file type. "
                            + "Check that WhatsApp is installed.",
                        details: nil
                    )
                )
            }
        }
    }

    /// Shows the system share sheet, the only route that carries several files
    /// or a file plus a caption.
    private func presentActivitySheet(
        _ files: [StagedFile],
        text: String?,
        args: [String: Any],
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.async {
            guard let host = UIApplication.topViewController() else {
                result(self.noViewControllerError())
                return
            }

            var items: [Any] = files.map(\.url)
            if let text { items.append(text) }

            let controller = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            // On iPad a share sheet is a popover and must be anchored, or UIKit
            // raises an exception when it is presented.
            if let popover = controller.popoverPresentationController {
                popover.sourceView = host.view
                popover.sourceRect = self.anchorRect(from: args, in: host.view)
                popover.permittedArrowDirections = .any
            }

            controller.completionWithItemsHandler = { activityType, completed, _, error in
                if let error {
                    result(
                        FlutterError(
                            code: "SHARE_FAILED",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                    return
                }
                if completed {
                    result(
                        self.successMap(
                            status: "sheetPresented",
                            target: nil,
                            message: activityType.map { "Shared to \($0.rawValue)." }
                        )
                    )
                } else {
                    result(self.successMap(status: "dismissed", target: nil, message: nil))
                }
            }

            host.present(controller, animated: true)
        }
    }

    // MARK: - UIDocumentInteractionControllerDelegate

    /// Drops the strong reference once the menu closes.
    ///
    /// The controller has to be retained while the menu is on screen because
    /// UIKit holds it weakly, but keeping it afterwards would pin the staged
    /// file for the lifetime of the plugin.
    public func documentInteractionControllerDidDismissOpenInMenu(
        _ controller: UIDocumentInteractionController
    ) {
        documentController = nil
    }

    // MARK: - Sticker packs

    private func addStickerPack(_ args: [String: Any], result: @escaping FlutterResult) {
        StickerPackPublisher.publish(args) { outcome in
            switch outcome {
            case .success(let added):
                result(added)
            case .failure(let error):
                result(
                    FlutterError(code: error.code, message: error.message, details: nil)
                )
            }
        }
    }

    // MARK: - Diagnostics

    /// Checks the host app's `Info.plist` for the entries iOS requires.
    ///
    /// Without `LSApplicationQueriesSchemes`, `canOpenURL` returns `false` for
    /// an app that is plainly installed, which surfaces to users as a wrong
    /// "WhatsApp is not installed" message. That misconfiguration is invisible
    /// at runtime unless something looks for it, which is what this does.
    private func diagnose() -> [String: Any] {
        var issues: [[String: String]] = []

        let declared = Bundle.main.object(
            forInfoDictionaryKey: "LSApplicationQueriesSchemes"
        ) as? [String] ?? []

        for target in Target.allCases where !declared.contains(target.scheme) {
            issues.append([
                "code": "MISSING_QUERY_SCHEME",
                "description": "Info.plist does not declare the '\(target.scheme)' URL "
                    + "scheme, so \(target.displayName) is reported as missing even when "
                    + "it is installed.",
                "remedy": "Add '\(target.scheme)' to the LSApplicationQueriesSchemes array "
                    + "in ios/Runner/Info.plist.",
            ])
        }

        return [
            "platform": "ios",
            "installedTargets": Target.allCases.filter(isInstalled).map(\.wireName),
            "issues": issues,
        ]
    }

    // MARK: - Helpers

    private func isInstalled(_ target: Target) -> Bool {
        guard let url = URL(string: "\(target.scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func arguments(_ call: FlutterMethodCall) -> [String: Any] {
        call.arguments as? [String: Any] ?? [:]
    }

    /// Resolves the popover anchor, defaulting to the centre of the screen.
    ///
    /// A zero-sized default would place an iPad popover in the top-left corner
    /// with its arrow pointing at nothing.
    private func anchorRect(from args: [String: Any], in view: UIView) -> CGRect {
        guard let origin = args["sharePositionOrigin"] as? [String: Any],
              let left = origin["left"] as? Double,
              let top = origin["top"] as? Double,
              let width = origin["width"] as? Double,
              let height = origin["height"] as? Double
        else {
            return CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        return CGRect(x: left, y: top, width: width, height: height)
    }

    /// Builds the result map sent back to Dart.
    ///
    /// Values are unwrapped into `[String: Any]` rather than left as optionals:
    /// a boxed `Optional` inside the dictionary is not something Flutter's
    /// standard codec can encode, and it fails at the channel boundary rather
    /// than at the call site.
    private func successMap(status: String, target: Target?, message: String?) -> [String: Any] {
        var map: [String: Any] = ["status": status]
        map["target"] = target?.wireName ?? NSNull()
        map["message"] = message ?? NSNull()
        return map
    }

    private func notInstalledError(_ target: Target) -> FlutterError {
        FlutterError(
            code: "APP_NOT_INSTALLED",
            message: "\(target.displayName) is not installed on this device.",
            details: nil
        )
    }

    private func noViewControllerError() -> FlutterError {
        FlutterError(
            code: "NO_ROOT_VIEW_CONTROLLER",
            message: "No view controller is available to present the share sheet from.",
            details: nil
        )
    }
}

// MARK: - Target

/// The WhatsApp apps this plugin can address, mirroring the Dart
/// `WhatsAppTarget` enum.
enum Target: String, CaseIterable {
    case standard
    case business

    init(wireName: String?) {
        self = wireName.flatMap(Target.init(rawValue:)) ?? .standard
    }

    var wireName: String { rawValue }

    var scheme: String {
        switch self {
        case .standard: return "whatsapp"
        case .business: return "whatsapp-business"
        }
    }

    var displayName: String {
        switch self {
        case .standard: return "WhatsApp"
        case .business: return "WhatsApp Business"
        }
    }

    /// The deep link that opens this app with a message pre-filled.
    func sendURL(phone: String?, text: String?) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "send"
        components.queryItems = queryItems(phone: phone, text: text)
        return components.url
    }

    /// The universal link that works with or without an installed app.
    static func waMeURL(phone: String?, text: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wa.me"
        components.path = "/\(phone ?? "")"
        if let text, !text.isEmpty {
            components.queryItems = [URLQueryItem(name: "text", value: text)]
        }
        return components.url
    }

    private func queryItems(phone: String?, text: String?) -> [URLQueryItem]? {
        var items: [URLQueryItem] = []
        if let phone, !phone.isEmpty {
            items.append(URLQueryItem(name: "phone", value: phone))
        }
        if let text, !text.isEmpty {
            items.append(URLQueryItem(name: "text", value: text))
        }
        return items.isEmpty ? nil : items
    }
}

// MARK: - View controller lookup

extension UIApplication {
    /// The view controller currently on screen, used to present share sheets.
    static func topViewController(
        controller: UIViewController? = UIApplication.keyRootViewController
    ) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topViewController(controller: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(controller: selected)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }

    /// The root view controller of the key window.
    ///
    /// The scene-based lookup is iOS 13 and later. This package declares a
    /// deployment target of iOS 12 so that it never forces a host app to raise
    /// its own target, which means the scene API has to sit behind an
    /// availability check rather than being used unguarded.
    private static var keyRootViewController: UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController
        }
        return UIApplication.shared.keyWindow?.rootViewController
    }
}
