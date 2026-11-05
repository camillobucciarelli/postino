import 'package:file/file.dart' show FileSystemException;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/platform_services.dart';
import '../domain/report_sharer.dart';
import 'report_sharer.dart';

Future<void> _sharePlus(String path, String subject) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'text/plain')],
      subject: subject,
    ),
  );
}

@module
abstract class ReportSharerModule() {
  /// Linux has no share sheet for files (share_plus throws): there the Save As dialog takes its place.
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<ReportSharer> reportSharer(FileSaver saver) async {
    const fs = LocalFileSystem();
    final temp = (await getTemporaryDirectory()).path;
    // On Android share_plus copies the file to its own cache folder: the decrypted text goes at the same time.
    final copies = fs.directory('$temp/share_plus');
    try {
      if (copies.existsSync()) await copies.delete(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('[segnalazione] cleanup: $e');
    }
    final linux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    return SystemReportSharer.open(
      fs.directory('$temp/postino-report'),
      linux ? (path, _) => saver.save(path, path.split('/').last) : _sharePlus,
    );
  }
}
