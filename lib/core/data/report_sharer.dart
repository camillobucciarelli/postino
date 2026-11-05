import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/report_sharer.dart';

/// Opens the system share sheet on a file ([path], [subject]).
typedef ShareFile = Future<void> Function(String path, String subject);

/// Shares the report through the system share sheet (share_plus). The decrypted text lives in the app's temporary
/// folder, which [open] empties: it never outlives the run that wrote it.
class SystemReportSharer._(final Directory _dir, final ShareFile _shareFile) implements ReportSharer {
  /// Deletes what an earlier run left in [dir].
  static Future<SystemReportSharer> open(Directory dir, ShareFile shareFile) async {
    if (dir.existsSync()) await dir.delete(recursive: true);
    return SystemReportSharer._(dir, shareFile);
  }

  @override
  Future<void> share({required String text, required String name, required String subject}) async {
    await _dir.create(recursive: true);
    final file = _dir.childFile(name);
    await file.writeAsString(text);
    await _shareFile(file.path, subject);
  }
}

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
  @preResolve
  @Singleton(env: [Environment.prod])
  Future<ReportSharer> reportSharer() async => SystemReportSharer.open(
    const LocalFileSystem().directory('${(await getTemporaryDirectory()).path}/postino-report'),
    _sharePlus,
  );
}
