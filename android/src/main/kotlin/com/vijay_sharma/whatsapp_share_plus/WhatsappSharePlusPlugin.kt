package com.vijay_sharma.whatsapp_share_plus

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

/**
 * Android implementation of `whatsapp_share_plus`.
 *
 * Work is split across three threads on purpose: argument parsing happens on
 * the platform thread, file staging on a background executor so a large video
 * never blocks the UI, and `startActivity` back on the main thread because
 * Android requires it.
 */
class WhatsappSharePlusPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var contextRef: WeakReference<Context> = WeakReference(null)
    private var activityBinding: ActivityPluginBinding? = null

    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Set while a sticker pack install is awaiting the user's decision. */
    private var pendingStickerResult: MethodChannel.Result? = null

    private val context: Context? get() = contextRef.get()
    private val activity: Activity? get() = activityBinding?.activity

    // region Plugin lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        contextRef = WeakReference(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        contextRef = WeakReference(null)
        backgroundExecutor.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // endregion

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isInstalled" -> result.success(isInstalled(targetPackage(call.argument("target"))))
            "installedTargets" -> result.success(installedTargets())
            "isStickerPackSupported" -> result.success(true)
            "share" -> backgroundExecutor.execute { share(call, result) }
            "openChat" -> openChat(call, result)
            "diagnose" -> result.success(diagnose())
            "addStickerPack" -> backgroundExecutor.execute { addStickerPack(call, result) }
            else -> result.notImplemented()
        }
    }

    // region Sharing

    private fun share(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.failOnMain(
            "NO_CONTEXT",
            "The application context is unavailable.",
        )

        val target = call.argument<String>("target") ?: TARGET_STANDARD
        val packageName = targetPackage(target)
        val text = call.argument<String>("text")
        val phone = call.argument<String>("phone")
        val rawFiles = call.argument<List<Map<*, *>>>("files").orEmpty()
        val allowFallback = call.argument<Boolean>("allowFallback") ?: true

        if (text.isNullOrEmpty() && rawFiles.isEmpty()) {
            return result.failOnMain(
                "INVALID_ARGUMENT",
                "A share needs text, at least one file, or both.",
            )
        }

        if (!isInstalled(packageName)) {
            // A link can carry text but never an attachment, so only a text-only
            // share has a meaningful fallback.
            if (allowFallback && rawFiles.isEmpty()) {
                return openLinkWithoutTarget(phone, text, result)
            }
            return result.failOnMain(
                "APP_NOT_INSTALLED",
                "${displayName(target)} is not installed on this device.",
            )
        }

        val stager = FileStager(context)
        val staged = try {
            stager.pruneOldSessions()
            stager.stage(rawFiles)
        } catch (error: FileNotFoundInShareException) {
            return result.failOnMain("FILE_NOT_FOUND", error.message ?: "File not found.")
        } catch (error: IOException) {
            return result.failOnMain(
                "FILE_ERROR",
                error.message ?: "The files could not be prepared for sharing.",
            )
        }

        val intent = ShareIntentBuilder.build(text, staged, phone, packageName)
        launch(intent) { launched ->
            if (launched) {
                result.success(
                    successMap(ShareStatus.OPENED, target, "Opened ${displayName(target)}."),
                )
            } else {
                result.error(
                    "APP_NOT_INSTALLED",
                    "${displayName(target)} could not handle this share.",
                    null,
                )
            }
        }
    }

    private fun openChat(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("target") ?: TARGET_STANDARD
        val packageName = targetPackage(target)
        val phone = call.argument<String>("phone")
        val text = call.argument<String>("text")
        val allowFallback = call.argument<Boolean>("allowFallback") ?: true

        if (!isInstalled(packageName)) {
            if (allowFallback) return openLinkWithoutTarget(phone, text, result)
            return result.failOnMain(
                "APP_NOT_INSTALLED",
                "${displayName(target)} is not installed on this device.",
            )
        }

        val intent = ShareIntentBuilder.openChatIntent(phone, text, packageName)
        launch(intent) { launched ->
            if (launched) {
                result.success(successMap(ShareStatus.OPENED, target, null))
            } else {
                result.error(
                    "APP_NOT_INSTALLED",
                    "${displayName(target)} could not open this chat.",
                    null,
                )
            }
        }
    }

    /**
     * Hands a `wa.me` link to whatever can open it — normally a browser, which
     * then bounces into WhatsApp if it turns up after all.
     */
    private fun openLinkWithoutTarget(
        phone: String?,
        text: String?,
        result: MethodChannel.Result,
    ) {
        val uri = Uri.parse("https://wa.me/${phone.orEmpty()}").buildUpon().apply {
            if (!text.isNullOrEmpty()) appendQueryParameter("text", text)
        }.build()

        launch(Intent(Intent.ACTION_VIEW, uri)) { launched ->
            if (launched) {
                result.success(
                    successMap(ShareStatus.FALLBACK, null, "Opened wa.me in a browser."),
                )
            } else {
                result.error(
                    "APP_NOT_INSTALLED",
                    "WhatsApp is not installed and no browser could open wa.me.",
                    null,
                )
            }
        }
    }

    /**
     * Starts [intent] on the main thread, preferring the current activity.
     *
     * The application context is only a fallback: starting from it requires
     * `FLAG_ACTIVITY_NEW_TASK`, which puts WhatsApp in a separate task and
     * makes the back gesture skip past the host app.
     */
    private fun launch(intent: Intent, onResult: (Boolean) -> Unit) {
        mainHandler.post {
            val activity = activity
            try {
                if (activity != null) {
                    activity.startActivity(intent)
                } else {
                    val context = context ?: return@post onResult(false)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
                onResult(true)
            } catch (error: ActivityNotFoundException) {
                onResult(false)
            }
        }
    }

    // endregion

    // region Sticker packs

    private fun addStickerPack(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.failOnMain(
            "NO_CONTEXT",
            "The application context is unavailable.",
        )

        val pack = call.arguments as? Map<*, *> ?: return result.failOnMain(
            "INVALID_ARGUMENT",
            "A sticker pack payload is required.",
        )

        val target = pack["target"] as? String ?: TARGET_STANDARD
        val packageName = targetPackage(target)
        if (!isInstalled(packageName)) {
            return result.failOnMain(
                "APP_NOT_INSTALLED",
                "${displayName(target)} is not installed on this device.",
            )
        }

        val stored = try {
            StickerPackStore.register(context, pack)
        } catch (error: IOException) {
            return result.failOnMain(
                "STICKER_PACK_ERROR",
                error.message ?: "The sticker pack could not be written to disk.",
            )
        }

        val providerAuthority = StickerContentProvider.authorityFor(context.packageName)
        if (context.packageManager.resolveContentProvider(providerAuthority, 0) == null) {
            return result.failOnMain(
                "STICKER_PACK_ERROR",
                "The sticker content provider is not registered. This usually means " +
                    "the plugin's manifest entries were removed by the app's manifest " +
                    "merger. Run WhatsAppShare.diagnose() for details.",
            )
        }

        mainHandler.post {
            val activity = activity
            if (activity == null) {
                result.error(
                    "NO_ACTIVITY",
                    "Installing a sticker pack needs a foreground activity. Call this " +
                        "while the app is visible.",
                    null,
                )
                return@post
            }
            if (pendingStickerResult != null) {
                result.error(
                    "STICKER_PACK_ERROR",
                    "Another sticker pack install is already awaiting confirmation.",
                    null,
                )
                return@post
            }

            val intent = Intent(WHATSAPP_ENABLE_STICKER_PACK_ACTION).apply {
                putExtra(EXTRA_STICKER_PACK_ID, stored.identifier)
                putExtra(EXTRA_STICKER_PACK_AUTHORITY, providerAuthority)
                putExtra(EXTRA_STICKER_PACK_NAME, stored.name)
                setPackage(packageName)
            }

            try {
                pendingStickerResult = result
                activity.startActivityForResult(intent, REQUEST_CODE_ADD_STICKER_PACK)
            } catch (error: ActivityNotFoundException) {
                pendingStickerResult = null
                result.error(
                    "STICKER_PACK_ERROR",
                    "This version of ${displayName(target)} does not accept third-party " +
                        "sticker packs.",
                    null,
                )
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_ADD_STICKER_PACK) return false
        val result = pendingStickerResult ?: return false
        pendingStickerResult = null

        // WhatsApp reports a rejected pack by cancelling with an explanation
        // attached, which is far more useful to surface than a bare `false`.
        val validationError = data?.getStringExtra(EXTRA_VALIDATION_ERROR)
        when {
            validationError != null -> result.error(
                "STICKER_PACK_REJECTED",
                "WhatsApp rejected the sticker pack: $validationError",
                null,
            )

            resultCode == Activity.RESULT_OK -> result.success(true)
            else -> result.success(false)
        }
        return true
    }

    // endregion

    // region Diagnostics

    private fun diagnose(): Map<String, Any?> {
        val context = context
        val issues = mutableListOf<Map<String, String>>()

        if (context == null) {
            issues.add(
                issue(
                    "NO_CONTEXT",
                    "The plugin has no application context.",
                    "This usually means the engine is detaching. Retry once the app is running.",
                ),
            )
            return mapOf(
                "platform" to "android",
                "installedTargets" to emptyList<String>(),
                "issues" to issues,
            )
        }

        val packageManager = context.packageManager

        val fileProviderAuthority = "${context.packageName}.${FileStager.FILE_PROVIDER_SUFFIX}"
        if (packageManager.resolveContentProvider(fileProviderAuthority, 0) == null) {
            issues.add(
                issue(
                    "MISSING_FILE_PROVIDER",
                    "The FileProvider at $fileProviderAuthority is not registered, so " +
                        "file sharing will fail.",
                    "The plugin declares it automatically. Check that the app's manifest " +
                        "does not remove it, and that no other library declares a provider " +
                        "with the same authority.",
                ),
            )
        }

        val stickerAuthority = StickerContentProvider.authorityFor(context.packageName)
        if (packageManager.resolveContentProvider(stickerAuthority, 0) == null) {
            issues.add(
                issue(
                    "MISSING_STICKER_PROVIDER",
                    "The sticker content provider at $stickerAuthority is not registered, " +
                        "so sticker packs cannot be installed.",
                    "The plugin declares it automatically. Check the app's manifest merger " +
                        "output if you need sticker support; other sharing is unaffected.",
                ),
            )
        }

        val installed = installedTargets()
        if (installed.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            issues.add(
                issue(
                    "NO_WHATSAPP_VISIBLE",
                    "Neither WhatsApp nor WhatsApp Business is visible to this app.",
                    "If WhatsApp is installed on the device, the <queries> entries this " +
                        "plugin contributes were dropped during manifest merging. Android 11 " +
                        "and above hide packages that are not declared there.",
                ),
            )
        }

        return mapOf(
            "platform" to "android",
            "installedTargets" to installed,
            "issues" to issues,
        )
    }

    // endregion

    // region Helpers

    private fun isInstalled(packageName: String): Boolean {
        val packageManager = context?.packageManager ?: return false
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (error: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun installedTargets(): List<String> = buildList {
        if (isInstalled(PACKAGE_STANDARD)) add(TARGET_STANDARD)
        if (isInstalled(PACKAGE_BUSINESS)) add(TARGET_BUSINESS)
    }

    private fun targetPackage(target: String?): String =
        if (target == TARGET_BUSINESS) PACKAGE_BUSINESS else PACKAGE_STANDARD

    private fun displayName(target: String?): String =
        if (target == TARGET_BUSINESS) "WhatsApp Business" else "WhatsApp"

    private fun successMap(status: String, target: String?, message: String?) =
        mapOf("status" to status, "target" to target, "message" to message)

    private fun issue(code: String, description: String, remedy: String) =
        mapOf("code" to code, "description" to description, "remedy" to remedy)

    /** Reports an error on the main thread, for use from the background executor. */
    private fun MethodChannel.Result.failOnMain(code: String, message: String) {
        mainHandler.post { error(code, message, null) }
    }

    // endregion

    /** Status strings shared with the Dart `ShareStatus` enum. */
    private object ShareStatus {
        const val OPENED = "opened"
        const val FALLBACK = "fallback"
    }

    private companion object {
        const val CHANNEL_NAME = "whatsapp_share_plus"

        const val PACKAGE_STANDARD = "com.whatsapp"
        const val PACKAGE_BUSINESS = "com.whatsapp.w4b"
        const val TARGET_STANDARD = "standard"
        const val TARGET_BUSINESS = "business"

        const val REQUEST_CODE_ADD_STICKER_PACK = 0x5741

        const val WHATSAPP_ENABLE_STICKER_PACK_ACTION =
            "com.whatsapp.intent.action.ENABLE_STICKER_PACK"
        const val EXTRA_STICKER_PACK_ID = "sticker_pack_id"
        const val EXTRA_STICKER_PACK_AUTHORITY = "sticker_pack_authority"
        const val EXTRA_STICKER_PACK_NAME = "sticker_pack_name"
        const val EXTRA_VALIDATION_ERROR = "validation_error"
    }
}
