#include "whatsapp_share_plus_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace whatsapp_share_plus {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "whatsapp_share_plus";
constexpr char kTargetStandard[] = "standard";
constexpr char kTargetBusiness[] = "business";

// Converts UTF-8 to the UTF-16 the Windows shell APIs expect.
std::wstring Utf16FromUtf8(const std::string &utf8) {
  if (utf8.empty()) return std::wstring();
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                   static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring utf16(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        utf16.data(), size);
  return utf16;
}

// Percent-encodes a UTF-8 string for use in a URL query value.
//
// Written by hand rather than with a shell helper because the Windows URL
// escaping functions leave several characters WhatsApp treats as delimiters
// untouched.
std::string PercentEncode(const std::string &value) {
  std::ostringstream encoded;
  encoded << std::hex << std::uppercase;
  for (unsigned char character : value) {
    bool unreserved = (character >= 'A' && character <= 'Z') ||
                      (character >= 'a' && character <= 'z') ||
                      (character >= '0' && character <= '9') ||
                      character == '-' || character == '_' ||
                      character == '.' || character == '~';
    if (unreserved) {
      encoded << character;
    } else {
      encoded << '%' << (character < 16 ? "0" : "")
              << static_cast<int>(character);
    }
  }
  return encoded.str();
}

// Reads an optional string argument, treating an empty string as absent.
std::string StringArgument(const EncodableMap &arguments, const char *key) {
  auto entry = arguments.find(EncodableValue(key));
  if (entry == arguments.end()) return std::string();
  const auto *value = std::get_if<std::string>(&entry->second);
  return value == nullptr ? std::string() : *value;
}

bool BoolArgument(const EncodableMap &arguments, const char *key,
                  bool fallback) {
  auto entry = arguments.find(EncodableValue(key));
  if (entry == arguments.end()) return fallback;
  const auto *value = std::get_if<bool>(&entry->second);
  return value == nullptr ? fallback : *value;
}

// Whether a URL protocol is registered with the shell.
//
// A registered protocol has a key under HKEY_CLASSES_ROOT carrying a
// "URL Protocol" value; that is what tells the shell an app claims it.
bool IsProtocolRegistered(const std::wstring &scheme) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CLASSES_ROOT, scheme.c_str(), 0, KEY_QUERY_VALUE,
                      &key) != ERROR_SUCCESS) {
    return false;
  }
  bool registered =
      ::RegQueryValueExW(key, L"URL Protocol", nullptr, nullptr, nullptr,
                         nullptr) == ERROR_SUCCESS;
  ::RegCloseKey(key);
  return registered;
}

std::wstring SchemeFor(const std::string &target) {
  return target == kTargetBusiness ? L"whatsapp-business" : L"whatsapp";
}

std::string DisplayNameFor(const std::string &target) {
  return target == kTargetBusiness ? "WhatsApp Business" : "WhatsApp";
}

// Hands a URL to the shell. Returns false when no app claimed it.
bool OpenUrl(const std::string &url) {
  std::wstring wide = Utf16FromUtf8(url);
  HINSTANCE outcome = ::ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr,
                                      nullptr, SW_SHOWNORMAL);
  // ShellExecuteW returns a value above 32 on success; anything at or below is
  // an error code in disguise.
  return reinterpret_cast<INT_PTR>(outcome) > 32;
}

std::string BuildSendUrl(const std::string &scheme, const std::string &phone,
                         const std::string &text) {
  std::string url = scheme + "://send";
  std::string separator = "?";
  if (!phone.empty()) {
    url += separator + "phone=" + PercentEncode(phone);
    separator = "&";
  }
  if (!text.empty()) {
    url += separator + "text=" + PercentEncode(text);
  }
  return url;
}

std::string BuildWaMeUrl(const std::string &phone, const std::string &text) {
  std::string url = "https://wa.me/" + phone;
  if (!text.empty()) url += "?text=" + PercentEncode(text);
  return url;
}

EncodableValue SuccessMap(const char *status, const std::string &target,
                          const std::string &message) {
  EncodableMap map;
  map[EncodableValue("status")] = EncodableValue(status);
  map[EncodableValue("target")] =
      target.empty() ? EncodableValue() : EncodableValue(target);
  map[EncodableValue("message")] = EncodableValue(message);
  return EncodableValue(map);
}

}  // namespace

void WhatsappSharePlusPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WhatsappSharePlusPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WhatsappSharePlusPlugin::WhatsappSharePlusPlugin() {}

WhatsappSharePlusPlugin::~WhatsappSharePlusPlugin() {}

void WhatsappSharePlusPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  const auto *arguments = std::get_if<EncodableMap>(method_call.arguments());
  EncodableMap empty;
  const EncodableMap &args = arguments == nullptr ? empty : *arguments;

  if (method == "isInstalled") {
    std::string target = StringArgument(args, "target");
    result->Success(EncodableValue(IsProtocolRegistered(SchemeFor(target))));
    return;
  }

  if (method == "installedTargets") {
    flutter::EncodableList targets;
    if (IsProtocolRegistered(L"whatsapp")) {
      targets.push_back(EncodableValue(kTargetStandard));
    }
    if (IsProtocolRegistered(L"whatsapp-business")) {
      targets.push_back(EncodableValue(kTargetBusiness));
    }
    result->Success(EncodableValue(targets));
    return;
  }

  if (method == "isStickerPackSupported") {
    result->Success(EncodableValue(false));
    return;
  }

  if (method == "addStickerPack") {
    result->Error("UNSUPPORTED_OPERATION",
                  "WhatsApp only accepts third-party sticker packs from its "
                  "Android and iOS apps.");
    return;
  }

  if (method == "diagnose") {
    flutter::EncodableList targets;
    if (IsProtocolRegistered(L"whatsapp")) {
      targets.push_back(EncodableValue(kTargetStandard));
    }
    if (IsProtocolRegistered(L"whatsapp-business")) {
      targets.push_back(EncodableValue(kTargetBusiness));
    }

    flutter::EncodableList issues;
    if (targets.empty()) {
      EncodableMap issue;
      issue[EncodableValue("code")] = EncodableValue("NO_WHATSAPP_DESKTOP");
      issue[EncodableValue("description")] = EncodableValue(
          "No app on this PC is registered for the whatsapp: URL protocol.");
      issue[EncodableValue("remedy")] = EncodableValue(
          "Install WhatsApp for Windows, or rely on the wa.me fallback, which "
          "opens WhatsApp Web in the default browser.");
      issues.push_back(EncodableValue(issue));
    }

    EncodableMap report;
    report[EncodableValue("platform")] = EncodableValue("windows");
    report[EncodableValue("installedTargets")] = EncodableValue(targets);
    report[EncodableValue("issues")] = EncodableValue(issues);
    result->Success(EncodableValue(report));
    return;
  }

  if (method == "share" || method == "openChat") {
    auto files_entry = args.find(EncodableValue("files"));
    bool has_files = false;
    if (files_entry != args.end()) {
      const auto *files = std::get_if<flutter::EncodableList>(&files_entry->second);
      has_files = files != nullptr && !files->empty();
    }

    if (has_files) {
      result->Error(
          "UNSUPPORTED_OPERATION",
          "Windows has no supported way to place a file into WhatsApp's "
          "compose window. Share text only, or copy the file yourself and let "
          "the user attach it.");
      return;
    }

    std::string target = StringArgument(args, "target");
    if (target.empty()) target = kTargetStandard;
    std::string text = StringArgument(args, "text");
    std::string phone = StringArgument(args, "phone");
    bool allow_fallback = BoolArgument(args, "allowFallback", true);

    std::wstring scheme = SchemeFor(target);
    if (IsProtocolRegistered(scheme)) {
      std::string scheme_utf8 =
          target == kTargetBusiness ? "whatsapp-business" : "whatsapp";
      if (OpenUrl(BuildSendUrl(scheme_utf8, phone, text))) {
        result->Success(
            SuccessMap("opened", target, "Opened " + DisplayNameFor(target) + "."));
        return;
      }
    }

    if (!allow_fallback) {
      result->Error("APP_NOT_INSTALLED",
                    DisplayNameFor(target) + " is not installed on this PC.");
      return;
    }

    if (OpenUrl(BuildWaMeUrl(phone, text))) {
      result->Success(SuccessMap("fallback", std::string(),
                                 "Opened wa.me in the default browser."));
      return;
    }

    result->Error("APP_NOT_INSTALLED",
                  DisplayNameFor(target) +
                      " is not installed and no browser could open wa.me.");
    return;
  }

  result->NotImplemented();
}

}  // namespace whatsapp_share_plus
