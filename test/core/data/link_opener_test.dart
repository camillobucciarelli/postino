// Opening outside Postino (#34): links through url_launcher; attachments (file:) through open_filex on iOS and
// the runner's channel on Android.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final file = Uri.file('/tmp/postino-attachments/x/Contratto.pdf');
  final link = Uri.parse('https://example.com/');

  /// What [opener] calls, the Android runner's channel included.
  late List<String> calls;
  SystemLinkOpener opener(TargetPlatform platform) => SystemLinkOpener.test(
    launch: (url) async => calls.add('url_launcher $url'),
    openFile: (path) async => calls.add('open_filex $path'),
    platform: platform,
  );

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(SystemLinkOpener.fileChannel, (call) async {
      calls.add('runner ${call.method} ${call.arguments}');
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(SystemLinkOpener.fileChannel, null));

  for (final (platform, fileWith) in [
    (TargetPlatform.android, 'runner open /tmp/postino-attachments/x/Contratto.pdf'),
    (TargetPlatform.iOS, 'open_filex /tmp/postino-attachments/x/Contratto.pdf'),
    (TargetPlatform.macOS, 'url_launcher $file'),
    (TargetPlatform.windows, 'url_launcher $file'),
    (TargetPlatform.linux, 'url_launcher $file'),
  ]) {
    test('${platform.name}: a file opens with ${fileWith.split(' ').first}, a link with url_launcher', () async {
      await opener(platform).open(file);
      await opener(platform).open(link);
      expect(calls, [fileWith, 'url_launcher $link']);
    });
  }

  for (final platform in TargetPlatform.values) {
    test('${platform.name}: an executable file is never opened (#75)', () async {
      await opener(platform).open(Uri.file('/tmp/postino-attachments/x/setup.exe'));
      expect(calls, isEmpty);
    });
  }

  test('a failure to open is swallowed, not thrown', () async {
    messenger.setMockMethodCallHandler(SystemLinkOpener.fileChannel, (_) => throw PlatformException(code: 'failed'));
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final opener = SystemLinkOpener.test(
        launch: (_) => throw Exception('no app'),
        openFile: (_) => throw Exception('no app'),
        platform: platform,
      );
      await opener.open(file);
      await opener.open(link);
    }
  });

  // No test runs the Kotlin: a name changed on one side only would open nothing, with no error (it is swallowed).
  test('the Android runner answers on the same channel, with the FileProvider the manifest declares', () {
    const android = 'android/app/src/main';
    final kotlin = File('$android/kotlin/com/cbucciarelli/postino/FileOpener.kt').readAsStringSync();
    final manifest = File('$android/AndroidManifest.xml').readAsStringSync();
    final paths = File('$android/res/xml/attachment_paths.xml').readAsStringSync();
    expect(kotlin, contains('const val CHANNEL = "${SystemLinkOpener.fileChannel.name}"'));
    expect(kotlin, contains('const val AUTHORITY_SUFFIX = ".attachments"'));
    expect(
      File('$android/kotlin/com/cbucciarelli/postino/AttachmentFileProvider.kt').readAsStringSync(),
      contains('class AttachmentFileProvider : FileProvider()'),
    );
    expect(manifest, contains('android:name=".AttachmentFileProvider"'));
    expect(manifest, contains(r'android:authorities="${applicationId}.attachments"'));
    expect(manifest, contains('android:resource="@xml/attachment_paths"'));
    // The folder of AttachmentModule's copies, under getTemporaryDirectory (Android's cache).
    expect(paths, contains('<cache-path name="attachments" path="postino-attachments/" />'));
    expect(File('lib/core/data/platform_services.dart').readAsStringSync(), contains("/postino-attachments'"));
  });
}
