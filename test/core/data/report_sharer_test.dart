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
    expect(shared, [('il log', 'Oggetto')]);
    expect(dir.childFile('postino-log.txt').existsSync(), isTrue);

    // The next start.
    await SystemReportSharer.open(dir, (_, _) async {});
    expect(dir.existsSync(), isFalse);
  });
}
