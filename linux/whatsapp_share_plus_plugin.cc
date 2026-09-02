#include "include/whatsapp_share_plus/whatsapp_share_plus_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#define WHATSAPP_SHARE_PLUS_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), whatsapp_share_plus_plugin_get_type(), \
                              WhatsappSharePlusPlugin))

struct _WhatsappSharePlusPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(WhatsappSharePlusPlugin, whatsapp_share_plus_plugin,
              g_object_get_type())

namespace {

constexpr char kChannelName[] = "whatsapp_share_plus";
constexpr char kTargetBusiness[] = "business";
constexpr char kTargetStandard[] = "standard";

// Reads an optional string argument, treating an empty string as absent.
const gchar* StringArgument(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  const gchar* text = fl_value_get_string(value);
  return (text == nullptr || strlen(text) == 0) ? nullptr : text;
}

gboolean BoolArgument(FlValue* args, const char* key, gboolean fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }
  return fl_value_get_bool(value);
}

gboolean HasFiles(FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* files = fl_value_lookup_string(args, "files");
  return files != nullptr && fl_value_get_type(files) == FL_VALUE_TYPE_LIST &&
         fl_value_get_length(files) > 0;
}

const gchar* SchemeFor(const gchar* target) {
  return (target != nullptr && strcmp(target, kTargetBusiness) == 0)
             ? "whatsapp-business"
             : "whatsapp";
}

const gchar* DisplayNameFor(const gchar* target) {
  return (target != nullptr && strcmp(target, kTargetBusiness) == 0)
             ? "WhatsApp Business"
             : "WhatsApp";
}

// Whether a desktop application claims a URL scheme.
gboolean IsSchemeHandled(const gchar* scheme) {
  GAppInfo* handler = g_app_info_get_default_for_uri_scheme(scheme);
  if (handler == nullptr) return FALSE;
  g_object_unref(handler);
  return TRUE;
}

// Hands a URI to the desktop environment.
gboolean OpenUri(const gchar* uri) {
  g_autoptr(GError) error = nullptr;
  gboolean launched = g_app_info_launch_default_for_uri(uri, nullptr, &error);
  if (!launched && error != nullptr) {
    g_warning("whatsapp_share_plus: could not open %s: %s", uri, error->message);
  }
  return launched;
}

// Builds `<scheme>://send?phone=…&text=…`, percent-encoding both values.
gchar* BuildSendUri(const gchar* scheme, const gchar* phone,
                    const gchar* text) {
  g_autoptr(GString) uri = g_string_new(scheme);
  g_string_append(uri, "://send");
  const gchar* separator = "?";
  if (phone != nullptr) {
    g_autofree gchar* escaped = g_uri_escape_string(phone, nullptr, FALSE);
    g_string_append_printf(uri, "%sphone=%s", separator, escaped);
    separator = "&";
  }
  if (text != nullptr) {
    g_autofree gchar* escaped = g_uri_escape_string(text, nullptr, FALSE);
    g_string_append_printf(uri, "%stext=%s", separator, escaped);
  }
  return g_strdup(uri->str);
}

gchar* BuildWaMeUri(const gchar* phone, const gchar* text) {
  g_autoptr(GString) uri = g_string_new("https://wa.me/");
  if (phone != nullptr) g_string_append(uri, phone);
  if (text != nullptr) {
    g_autofree gchar* escaped = g_uri_escape_string(text, nullptr, FALSE);
    g_string_append_printf(uri, "?text=%s", escaped);
  }
  return g_strdup(uri->str);
}

FlValue* InstalledTargets() {
  FlValue* targets = fl_value_new_list();
  if (IsSchemeHandled("whatsapp")) {
    fl_value_append_take(targets, fl_value_new_string(kTargetStandard));
  }
  if (IsSchemeHandled("whatsapp-business")) {
    fl_value_append_take(targets, fl_value_new_string(kTargetBusiness));
  }
  return targets;
}

FlMethodResponse* SuccessResponse(const char* status, const gchar* target,
                                  const char* message) {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "status", fl_value_new_string(status));
  fl_value_set_string_take(
      result, "target",
      target == nullptr ? fl_value_new_null() : fl_value_new_string(target));
  fl_value_set_string_take(result, "message", fl_value_new_string(message));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* HandleShare(FlValue* args) {
  if (HasFiles(args)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "UNSUPPORTED_OPERATION",
        "Linux has no supported way to place a file into WhatsApp's compose "
        "window. Share text only.",
        nullptr));
  }

  const gchar* target = StringArgument(args, "target");
  if (target == nullptr) target = kTargetStandard;
  const gchar* text = StringArgument(args, "text");
  const gchar* phone = StringArgument(args, "phone");
  gboolean allow_fallback = BoolArgument(args, "allowFallback", TRUE);

  const gchar* scheme = SchemeFor(target);
  if (IsSchemeHandled(scheme)) {
    g_autofree gchar* uri = BuildSendUri(scheme, phone, text);
    if (OpenUri(uri)) {
      g_autofree gchar* message =
          g_strdup_printf("Opened %s.", DisplayNameFor(target));
      return SuccessResponse("opened", target, message);
    }
  }

  if (!allow_fallback) {
    g_autofree gchar* message = g_strdup_printf(
        "%s is not installed on this system.", DisplayNameFor(target));
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("APP_NOT_INSTALLED", message, nullptr));
  }

  g_autofree gchar* fallback = BuildWaMeUri(phone, text);
  if (OpenUri(fallback)) {
    return SuccessResponse("fallback", nullptr,
                           "Opened wa.me in the default browser.");
  }

  g_autofree gchar* message = g_strdup_printf(
      "%s is not installed and no browser could open wa.me.",
      DisplayNameFor(target));
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new("APP_NOT_INSTALLED", message, nullptr));
}

FlMethodResponse* HandleDiagnose() {
  g_autoptr(FlValue) targets = InstalledTargets();
  g_autoptr(FlValue) issues = fl_value_new_list();

  if (fl_value_get_length(targets) == 0) {
    FlValue* issue = fl_value_new_map();
    fl_value_set_string_take(issue, "code",
                             fl_value_new_string("NO_WHATSAPP_DESKTOP"));
    fl_value_set_string_take(
        issue, "description",
        fl_value_new_string(
            "No desktop application on this system handles the whatsapp:// "
            "URL scheme."));
    fl_value_set_string_take(
        issue, "remedy",
        fl_value_new_string(
            "WhatsApp has no official Linux desktop app. Text sharing still "
            "works through the wa.me fallback, which opens WhatsApp Web."));
    fl_value_append_take(issues, issue);
  }

  g_autoptr(FlValue) report = fl_value_new_map();
  fl_value_set_string_take(report, "platform", fl_value_new_string("linux"));
  fl_value_set_string(report, "installedTargets", targets);
  fl_value_set_string(report, "issues", issues);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(report));
}

void MethodCallHandler(FlMethodChannel* channel, FlMethodCall* method_call,
                       gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "isInstalled") == 0) {
    const gchar* target = StringArgument(args, "target");
    g_autoptr(FlValue) result =
        fl_value_new_bool(IsSchemeHandled(SchemeFor(target)));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "installedTargets") == 0) {
    g_autoptr(FlValue) targets = InstalledTargets();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(targets));
  } else if (strcmp(method, "isStickerPackSupported") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "addStickerPack") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "UNSUPPORTED_OPERATION",
        "WhatsApp only accepts third-party sticker packs from its Android and "
        "iOS apps.",
        nullptr));
  } else if (strcmp(method, "share") == 0 || strcmp(method, "openChat") == 0) {
    response = HandleShare(args);
  } else if (strcmp(method, "diagnose") == 0) {
    response = HandleDiagnose();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("whatsapp_share_plus: failed to send response: %s",
              error->message);
  }
}

}  // namespace

static void whatsapp_share_plus_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(whatsapp_share_plus_plugin_parent_class)->dispose(object);
}

static void whatsapp_share_plus_plugin_class_init(
    WhatsappSharePlusPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = whatsapp_share_plus_plugin_dispose;
}

static void whatsapp_share_plus_plugin_init(WhatsappSharePlusPlugin* self) {}

void whatsapp_share_plus_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  WhatsappSharePlusPlugin* plugin = WHATSAPP_SHARE_PLUS_PLUGIN(
      g_object_new(whatsapp_share_plus_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, MethodCallHandler, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
