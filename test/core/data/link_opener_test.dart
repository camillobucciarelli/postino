// Opening outside Postino (#34): links through url_launcher; attachments (file:) through open_filex on iOS and
// the runner's channel on Android.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/platform_services.dart';

void main() {
  final file = Uri.file('/tmp/postino-attachments/x/Contratto.pdf');
  final link = Uri.parse('https://example.com/');

  for (final (platform, fileWith) in [
    (TargetPlatform.android, 'open_filex'),
    (TargetPlatform.iOS, 'open_filex'),
    (TargetPlatform.macOS, 'url_launcher'),
    (TargetPlatform.windows, 'url_launcher'),
    (TargetPlatform.linux, 'url_launcher'),
  ]) {
    test('${platform.name}: a file opens with $fileWith, a link with url_launcher', () async {
      final calls = <String>[];
      final opener = SystemLinkOpener.test(
        launch: (url) async => calls.add('url_launcher $url'),
        openFile: (path) async => calls.add('open_filex $path'),
        platform: platform,
      );
      await opener.open(file);
      await opener.open(link);
      expect(calls, [
        fileWith == 'open_filex' ? 'open_filex /tmp/postino-attachments/x/Contratto.pdf' : 'url_launcher $file',
        'url_launcher $link',
      ]);
    });
  }

  for (final platform in TargetPlatform.values) {
    test('${platform.name}: an executable file is never opened (#75)', () async {
      final calls = <String>[];
      final opener = SystemLinkOpener.test(
        launch: (url) async => calls.add('url_launcher $url'),
        openFile: (path) async => calls.add('open_filex $path'),
        platform: platform,
      );
      await opener.open(Uri.file('/tmp/postino-attachments/x/setup.exe'));
      expect(calls, isEmpty);
    });
  }

  test('a failure to open is swallowed, not thrown', () async {
    final opener = SystemLinkOpener.test(
      launch: (_) => throw Exception('no app'),
      openFile: (_) => throw Exception('no app'),
      platform: TargetPlatform.android,
    );
    await opener.open(file);
    await opener.open(link);
  });

  test('Android: a file goes to the runner\'s channel, not to open_filex', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <(String, String, Object?)>[];
    for (final channel in [SystemLinkOpener.fileChannel, const MethodChannel('open_file')]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add((channel.name, call.method, call.arguments));
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await SystemLinkOpener().open(file);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(calls, [('it.postino/file_opener', 'open', '/tmp/postino-attachments/x/Contratto.pdf')]);
  });
}
