package com.vijay_sharma.whatsapp_share_plus

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.lang.ref.WeakReference

class WhatsappSharePlusPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private lateinit var contextRef: WeakReference<Context>

  private val providerAuthority: String by lazy {
    "${getContext().packageName}.whatsapp_share_plus.fileprovider"
  }

  private val shareCacheFolder: File
    get() = File(getContext().cacheDir, "whatsapp_share_plus")

  private fun getContext(): Context {
    return contextRef.get()!!
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "whatsapp_share_plus")
    channel.setMethodCallHandler(this)
    contextRef = WeakReference(binding.applicationContext)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
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
        clearShareCacheFolder()
        share(call, result, "com.whatsapp")
      }
      "shareToWhatsappBusiness" -> {
        clearShareCacheFolder()
        share(call, result, "com.whatsapp.w4b")
      }
      else -> result.notImplemented()
    }
  }

  private fun isPackageInstalled(packageName: String): Boolean {
    return try {
      getContext().packageManager.getPackageInfo(packageName, 0)
      true
    } catch (e: PackageManager.NameNotFoundException) {
      false
    }
  }

  private fun clearShareCacheFolder() {
    val folder = shareCacheFolder
    if (folder.exists()) {
      folder.listFiles()?.forEach { it.delete() }
      folder.delete()
    }
  }

  @Throws(IOException::class)
  private fun copyToShareCache(file: File): File {
    if (!shareCacheFolder.exists()) {
      shareCacheFolder.mkdirs()
    }
    val destFile = File(shareCacheFolder, file.name)
    file.copyTo(destFile, overwrite = true)
    return destFile
  }

  private fun share(call: MethodCall, result: MethodChannel.Result, packageName: String) {
    try {
      val text = call.argument<String>("text")
      val imagePath = call.argument<String>("imagePath")
      val phone = call.argument<String>("phone")

      val context = getContext()

      val intent = Intent().apply {
        action = Intent.ACTION_SEND
        type = if (imagePath != null) "image/*" else "text/plain"
        setPackage(packageName)

        text?.let { putExtra(Intent.EXTRA_TEXT, it) }

        if (!phone.isNullOrEmpty()) {
          putExtra("jid", "$phone@s.whatsapp.net")
        }

        if (!imagePath.isNullOrEmpty()) {
          val originalFile = File(imagePath)
          val cachedFile = copyToShareCache(originalFile)
          val uri: Uri = FileProvider.getUriForFile(context, providerAuthority, cachedFile)
          putExtra(Intent.EXTRA_STREAM, uri)
          addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }

      context.startActivity(intent)
      result.success(true)
    } catch (e: Exception) {
      result.error("WHATSAPP_SHARE_ERROR", e.message, null)
    }
  }
}
