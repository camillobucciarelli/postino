import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/report_sharer.dart';

void main() {
  test('the decrypted file is written for the share sheet and deleted at the next start', () async {
    final fs = MemoryFileSystem();
    final dir = fs.directory('/tmp/postino-report');
    final shared = <(String, String)>[];
    final sharer = await SystemReportSharer.open(dir, (path, subject) async {
      shared.add((fs.file(path).readAsStringSync(), subject));
    });

    await sharer.share(text: 'il log', name: 'postino-log.txt', subject: 'Oggetto');
    expect(shared.first, ('il log', 'Oggetto'));

    // Each share has its own folder: a target still reading the first file does not see the second overwrite it.
    await sharer.share(text: 'altro', name: 'postino-log.txt', subject: 'Oggetto');
    expect(dir.listSync(recursive: true).whereType<File>(), hasLength(2));

    // The next start.
    await SystemReportSharer.open(dir, (_, _) async {});
    expect(dir.existsSync(), isFalse);
  });
}
