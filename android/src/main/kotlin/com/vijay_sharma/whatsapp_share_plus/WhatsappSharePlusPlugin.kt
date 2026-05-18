package com.vijay_sharma.whatsapp_share_plus

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

class WhatsappSharePlusPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private var contextRef: WeakReference<Context> = WeakReference(null)

  private val providerAuthority: String
    get() = "${getContext()?.packageName}.whatsapp_share_plus.fileprovider"

  private val shareCacheFolder: File?
    get() = getContext()?.cacheDir?.let { File(it, "whatsapp_share_plus") }

  private val backgroundExecutor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  private fun getContext(): Context? = contextRef.get()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "whatsapp_share_plus")
    channel.setMethodCallHandler(this)
    contextRef = WeakReference(binding.applicationContext)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    contextRef = WeakReference(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isWhatsappInstalled" -> {
        result.success(isPackageInstalled("com.whatsapp"))
      }
      "isWhatsappBusinessInstalled" -> {
        result.success(isPackageInstalled("com.whatsapp.w4b"))
      }
      "shareToWhatsapp" -> {
        backgroundExecutor.execute {
          clearShareCacheFolder()
          share(call, result, "com.whatsapp")
        }
      }
      "shareToWhatsappBusiness" -> {
        backgroundExecutor.execute {
          clearShareCacheFolder()
          share(call, result, "com.whatsapp.w4b")
        }
      }
      "shareImageToWhatsapp" -> {
        backgroundExecutor.execute {
          clearShareCacheFolder()
          share(call, result, "com.whatsapp")
        }
      }
      "shareImageToWhatsappBusiness" -> {
        backgroundExecutor.execute {
          clearShareCacheFolder()
          share(call, result, "com.whatsapp.w4b")
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun isPackageInstalled(packageName: String): Boolean {
    val context = getContext() ?: return false
    return try {
      context.packageManager.getPackageInfo(packageName, 0)
      true
    } catch (e: PackageManager.NameNotFoundException) {
      false
    }
  }

  private fun clearShareCacheFolder() {
    shareCacheFolder?.let { folder ->
      if (folder.exists()) {
        folder.listFiles()?.forEach { it.delete() }
        folder.delete()
      }
    }
  }

  @Throws(IOException::class)
  private fun copyToShareCache(file: File): File {
    val cacheFolder = shareCacheFolder
      ?: throw IOException("Cache directory unavailable")
    if (!cacheFolder.exists()) {
      cacheFolder.mkdirs()
    }
    val destFile = File(cacheFolder, file.name)
    file.copyTo(destFile, overwrite = true)
    return destFile
  }

  private fun share(call: MethodCall, result: MethodChannel.Result, packageName: String) {
    val context = getContext()
    if (context == null) {
      mainHandler.post { result.error("NO_CONTEXT", "Application context is unavailable", null) }
      return
    }

    try {
      val text = call.argument<String>("text")
      val imagePath = call.argument<String>("imagePath")
      val phone = call.argument<String>("phone")

      // Validate that at least one of text or image is provided
      if (text.isNullOrEmpty() && imagePath.isNullOrEmpty()) {
        mainHandler.post {
          result.error("INVALID_ARGUMENT", "Either text or imagePath must be provided", null)
        }
        return
      }

      val intent = Intent().apply {
        action = Intent.ACTION_SEND
        type = if (!imagePath.isNullOrEmpty()) "image/*" else "text/plain"
        setPackage(packageName)

        text?.let { putExtra(Intent.EXTRA_TEXT, it) }

        if (!phone.isNullOrEmpty()) {
          putExtra("jid", "$phone@s.whatsapp.net")
        }

        if (!imagePath.isNullOrEmpty()) {
          val originalFile = File(imagePath)
          if (!originalFile.exists()) {
            mainHandler.post {
              result.error("FILE_NOT_FOUND", "Image file not found at path: $imagePath", null)
            }
            return@apply
          }
          val cachedFile = copyToShareCache(originalFile)
          val uri: Uri = FileProvider.getUriForFile(context, providerAuthority, cachedFile)
          putExtra(Intent.EXTRA_STREAM, uri)
          addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }

      // Only start activity if intent was fully built (no early return above)
      if (!imagePath.isNullOrEmpty() && !intent.hasExtra(Intent.EXTRA_STREAM)) {
        // Early return was triggered inside apply block — do nothing, result already sent
        return
      }

      context.startActivity(intent)
      mainHandler.post { result.success(true) }
    } catch (e: Exception) {
      mainHandler.post { result.error("WHATSAPP_SHARE_ERROR", e.message, null) }
    }
  }
}
