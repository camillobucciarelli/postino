package com.cbucciarelli.postino

import androidx.core.content.FileProvider

/// Hands the attachments' copies (res/xml/attachment_paths.xml), and nothing else, to the app that opens one.
/// A class of its own: a FileProvider declared by its androidx name would clash with another library's.
class AttachmentFileProvider : FileProvider()
