package com.cbucciarelli.postino

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import java.io.File

/// Opens an attachment's copy (a file of the app's cache) in another app. In place of open_filex on Android: its
/// plugin drops its channel when an Activity goes and never takes it back, so on the engine that outlives the
/// Activity (#214) a second Activity opened nothing.
object FileOpener {
    /// Dart's side: SystemLinkOpener in lib/core/data/platform_services.dart.
    const val CHANNEL = "it.postino/file_opener"

    /// Added to the applicationId: the authority of [AttachmentFileProvider] in the manifest.
    private const val AUTHORITY_SUFFIX = ".attachments"

    /// The app is picked by the type of the file's extension. With no app for it the system's chooser says so.
    fun open(activity: Activity, path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(activity, activity.packageName + AUTHORITY_SUFFIX, file)
        val type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "*/*"
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivity(view)
        } catch (e: ActivityNotFoundException) {
            activity.startActivity(Intent.createChooser(view, null))
        }
    }
}
