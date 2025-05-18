import Flutter
import UIKit
import Photos

public class WhatsappSharePlusPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "whatsapp_share_plus", binaryMessenger: registrar.messenger())
    let instance = WhatsappSharePlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isWhatsappInstalled":
      result(isAppInstalled(urlScheme: "whatsapp://"))
    case "isWhatsappBusinessInstalled":
      result(isAppInstalled(urlScheme: "whatsapp-business://"))
    case "shareText":
      if let args = call.arguments as? [String: Any], let text = args["text"] as? String {
        shareText(text: text, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Text argument missing", details: nil))
      }
    case "shareImage":
      if let args = call.arguments as? [String: Any], let imagePath = args["imagePath"] as? String {
        shareImage(imagePath: imagePath, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path missing", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func isAppInstalled(urlScheme: String) -> Bool {
    guard let url = URL(string: urlScheme) else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private func shareText(text: String, result: @escaping FlutterResult) {
    guard let whatsappURL = URL(string: "whatsapp://send?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
      result(FlutterError(code: "URL_ERROR", message: "Cannot create URL", details: nil))
      return
    }
    if UIApplication.shared.canOpenURL(whatsappURL) {
      UIApplication.shared.open(whatsappURL, options: [:], completionHandler: { success in
        result(success)
      })
    } else {
      result(false)
    }
  }

  private func shareImage(imagePath: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: imagePath)
    if !FileManager.default.fileExists(atPath: imagePath) {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Image file not found", details: nil))
      return
    }

    let docController = UIDocumentInteractionController(url: fileURL)
    docController.uti = "net.whatsapp.image"

    DispatchQueue.main.async {
      if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
        docController.presentOpenInMenu(from: rootVC.view.frame, in: rootVC.view, animated: true)
        result(true)
      } else {
        result(FlutterError(code: "NO_ROOT_VIEW_CONTROLLER", message: "Cannot find root view controller", details: nil))
      }
    }
  }
}
