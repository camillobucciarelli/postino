import 'package:file/file.dart';
import 'package:flutter/foundation.dart';

import '../domain/report_sharer.dart';

/// Opens the system share sheet on a file ([path], [subject]).
typedef ShareFile = Future<void> Function(String path, String subject);

/// Shares the report through [_shareFile] (the system share sheet, share_plus). The decrypted text lives in the
/// app's temporary folder [_dir], which [open] empties: it never outlives the run that wrote it.
class SystemReportSharer._(final Directory _dir, final ShareFile _shareFile) implements ReportSharer {
  /// Deletes what an earlier run left in [dir].
  static Future<SystemReportSharer> open(Directory dir, ShareFile shareFile) async {
    // Best effort: a folder still held by a share target must not keep Postino from starting.
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('[segnalazione] cleanup: $e');
    }
    return SystemReportSharer._(dir, shareFile);
  }

  @override
  Future<void> share({required String text, required String name, required String subject}) async {
    // A folder per share: a target still reading the first file does not see the next report overwrite it.
    await _dir.create(recursive: true);
    final file = (await _dir.createTemp('report-')).childFile(name);
    await file.writeAsString(text);
    await _shareFile(file.path, subject);
  }
}
