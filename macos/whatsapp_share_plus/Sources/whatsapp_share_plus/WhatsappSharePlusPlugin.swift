import AppKit
import FlutterMacOS

/// macOS implementation of `whatsapp_share_plus`.
///
/// The WhatsApp desktop app registers the `whatsapp://` URL scheme, so text
/// shares open it directly. Files take a different route: macOS has no way to
/// push a file into a named app, so they go through `NSSharingServicePicker`,
/// where WhatsApp appears alongside the system's other share destinations.
public class WhatsappSharePlusPlugin: NSObject, FlutterPlugin {

    /// Retained while the picker is on screen; AppKit holds it weakly.
    private var sharingPicker: NSSharingServicePicker?

    /// Used to anchor the picker when the caller gives no origin rect.
    private weak var hostView: NSView?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "whatsapp_share_plus",
            binaryMessenger: registrar.messenger
        )
        let instance = WhatsappSharePlusPlugin()
        instance.hostView = registrar.view
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "isInstalled":
            result(isInstalled(Target(wireName: args["target"] as? String)))

        case "installedTargets":
            result(Target.allCases.filter(isInstalled).map(\.wireName))

        case "isStickerPackSupported":
            result(false)

        case "addStickerPack":
            result(
                FlutterError(
                    code: "UNSUPPORTED_OPERATION",
                    message: "WhatsApp only accepts third-party sticker packs from its "
                        + "Android and iOS apps.",
                    details: nil
                )
            )

        case "share":
            share(args, result: result)

        case "openChat":
            shareText(
                text: args["text"] as? String,
                phone: args["phone"] as? String,
                target: Target(wireName: args["target"] as? String),
                allowFallback: args["allowFallback"] as? Bool ?? true,
                result: result
            )

        case "diagnose":
            result([
                "platform": "macos",
                "installedTargets": Target.allCases.filter(isInstalled).map(\.wireName),
                "issues": issues(),
            ])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Sharing

    private func share(_ args: [String: Any], result: @escaping FlutterResult) {
        let files = args["files"] as? [[String: Any]] ?? []
        let text = (args["text"] as? String).flatMap { $0.isEmpty ? nil : $0 }

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
            shareText(
                text: text,
                phone: args["phone"] as? String,
                target: Target(wireName: args["target"] as? String),
                allowFallback: args["allowFallback"] as? Bool ?? true,
                result: result
            )
            return
        }

        do {
            let staged = try stage(files)
            presentSharingPicker(staged, text: text, args: args, result: result)
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
        let message = (text?.isEmpty ?? true) ? nil : text
        let recipient = (phone?.isEmpty ?? true) ? nil : phone

        if isInstalled(target), let url = target.sendURL(phone: recipient, text: message) {
            NSWorkspace.shared.open(url)
            result(Self.successMap(
                status: "opened",
                target: target.wireName,
                message: "Opened \(target.displayName)."
            ))
            return
        }

        guard allowFallback, let fallback = Target.waMeURL(phone: recipient, text: message) else {
            result(
                FlutterError(
                    code: "APP_NOT_INSTALLED",
                    message: "\(target.displayName) is not installed on this Mac.",
                    details: nil
                )
            )
            return
        }

        NSWorkspace.shared.open(fallback)
        result(Self.successMap(
            status: "fallback",
            target: nil,
            message: "Opened wa.me in the default browser."
        ))
    }

    /// Shows the macOS share picker with the staged files.
    private func presentSharingPicker(
        _ files: [URL],
        text: String?,
        args: [String: Any],
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.async {
            guard let view = self.hostView, let window = view.window else {
                result(
                    FlutterError(
                        code: "NO_ROOT_VIEW_CONTROLLER",
                        message: "No window is available to present the share picker from.",
                        details: nil
                    )
                )
                return
            }

            var items: [Any] = files
            if let text { items.append(text) }

            let picker = NSSharingServicePicker(items: items)
            self.sharingPicker = picker

            let anchor = self.anchorRect(from: args, in: view)
            picker.show(relativeTo: anchor, of: window.contentView ?? view, preferredEdge: .minY)

            result(Self.successMap(
                status: "sheetPresented",
                target: nil,
                message: "Presented the macOS share picker."
            ))
        }
    }

    /// Copies files into a temporary directory so the picker reads from a
    /// stable location the app controls.
    private func stage(_ files: [[String: Any]]) throws -> [URL] {
        let session = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatsapp_share_plus", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        return try files.enumerated().map { index, raw in
            let name = (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "attachment_\(index)"
            let destination = session.appendingPathComponent(
                name.replacingOccurrences(of: "/", with: "_")
            )

            if let typed = raw["bytes"] as? FlutterStandardTypedData {
                try typed.data.write(to: destination)
            } else if let path = raw["path"] as? String {
                guard FileManager.default.fileExists(atPath: path) else {
                    throw NSError(
                        domain: "whatsapp_share_plus",
                        code: 404,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Image file not found at path: \(path)",
                        ]
                    )
                }
                try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: destination)
            } else {
                throw NSError(
                    domain: "whatsapp_share_plus",
                    code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "A share file must carry either a path or bytes.",
                    ]
                )
            }
            return destination
        }
    }

    // MARK: - Helpers

    /// Builds the result map sent back to Dart.
    ///
    /// Values are unwrapped rather than left as optionals: a boxed `Optional`
    /// inside the dictionary is not something Flutter's standard codec can
    /// encode.
    private static func successMap(
        status: String,
        target: String?,
        message: String?
    ) -> [String: Any] {
        var map: [String: Any] = ["status": status]
        map["target"] = target ?? NSNull()
        map["message"] = message ?? NSNull()
        return map
    }

    private func isInstalled(_ target: Target) -> Bool {
        guard let url = URL(string: "\(target.scheme)://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    private func issues() -> [[String: String]] {
        guard Target.allCases.filter(isInstalled).isEmpty else { return [] }
        return [[
            "code": "NO_WHATSAPP_DESKTOP",
            "description": "No app on this Mac handles the whatsapp:// URL scheme.",
            "remedy": "Install WhatsApp for macOS, or rely on the wa.me fallback, which "
                + "opens WhatsApp Web in the default browser.",
        ]]
    }

    private func anchorRect(from args: [String: Any], in view: NSView) -> NSRect {
        guard let origin = args["sharePositionOrigin"] as? [String: Any],
              let left = origin["left"] as? Double,
              let top = origin["top"] as? Double,
              let width = origin["width"] as? Double,
              let height = origin["height"] as? Double
        else {
            return NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        return NSRect(x: left, y: top, width: width, height: height)
    }
}

/// The WhatsApp apps this plugin can address, mirroring the Dart
/// `WhatsAppTarget` enum.
enum Target: String, CaseIterable {
    case standard
    case business

    init(wireName: String?) {
        self = wireName.flatMap(Target.init(rawValue:)) ?? .standard
    }

    var wireName: String { rawValue }

    /// macOS ships one WhatsApp desktop app, which claims `whatsapp://`.
    /// WhatsApp Business has no desktop build, so it resolves to the same
    /// scheme and is reported as absent unless that app is installed.
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

    func sendURL(phone: String?, text: String?) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "send"
        var items: [URLQueryItem] = []
        if let phone, !phone.isEmpty { items.append(URLQueryItem(name: "phone", value: phone)) }
        if let text, !text.isEmpty { items.append(URLQueryItem(name: "text", value: text)) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }

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
}
