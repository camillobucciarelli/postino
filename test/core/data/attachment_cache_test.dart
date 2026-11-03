// Attachment cache (#34): encrypted at rest, LRU under a cap, decrypted copies gone at the next launch.
import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart' show FileSystemOp;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/attachment_cache.dart';
import 'package:postino/core/domain/attachment_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;
AttachmentRepository get cache => getIt<AttachmentRepository>();

/// 60 bytes of recognisable text.
List<int> _content(String tag) => utf8.encode(tag.padRight(60, '.'));

Future<void> _start({int? cap}) async {
  h = await Harness.create(attachmentCap: cap);
  gmail = await h.addAccount('a1');
  gmail.deliver(msg('m1'));
}

Future<Result<String>> _file(Attachment a, {Future<void>? cancel}) =>
    cache.file('a1', 'm1', a, cancel: cancel);

String _ok(Result<String> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Directory get _cacheDir => h.fs.directory('/support/attachments');
List<File> get _cached => _cacheDir.listSync().whereType<File>().toList();

void main() {
  tearDown(() => getIt.reset());

  test(
    'the first use downloads, the next ones open from the cache offline',
    () async {
      await _start();
      final a = gmail.attach('m1', 'Contratto.pdf', _content('contratto'));
      final first = _ok(await _file(a));
      expect(h.fs.file(first).readAsBytesSync(), _content('contratto'));
      expect(h.fs.file(first).basename, 'Contratto.pdf');

      gmail.goOffline();
      final second = _ok(await _file(a));
      expect(h.fs.file(second).readAsBytesSync(), _content('contratto'));
      expect(gmail.attachmentCalls, hasLength(1));
    },
  );

  test('offline, an attachment never downloaded is OfflineFailure', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    gmail.goOffline();
    expect(
      await _file(a),
      isA<Err<String>>().having(
        (e) => e.failure,
        'failure',
        isA<OfflineFailure>(),
      ),
    );
  });

  test('cached files are not readable in clear', () async {
    await _start();
    final a = gmail.attach('m1', 'segreto.txt', _content('segreto'));
    _ok(await _file(a));
    final stored = _cached.single.readAsBytesSync();
    expect(stored.length, 60 + AttachmentCache.overhead);
    expect(latin1.decode(stored), isNot(contains('segreto')));
    expect(h.keychain.values['attachments_key'], hasLength(128));
  });

  test('a damaged cached file is downloaded again', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    _ok(await _file(a));
    final f = _cached.single;
    final bytes = f.readAsBytesSync()..[20] ^= 1;
    f.writeAsBytesSync(bytes);
    final path = _ok(await _file(a));
    expect(h.fs.file(path).readAsBytesSync(), _content('a'));
    expect(gmail.attachmentCalls, hasLength(2));
  });

  test('the decrypted copies older than an hour are gone at the next launch, a recent one stays, the cache stays', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    final path = _ok(await _file(a));
    expect(h.fs.file(path).existsSync(), isTrue);
    // One left by a previous launch, and the one another app has just opened (the foreground, while a
    // background isolate starts): the copy just made.
    final old = h.fs.file('/tmp/postino-attachments/old.pdf')
      ..writeAsBytesSync([1])
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

    // A new launch on the same disk.
    await AttachmentStorage.open(
      _cacheDir,
      h.fs.directory('/tmp/postino-attachments'),
    );
    expect(old.existsSync(), isFalse);
    expect(h.fs.file(path).existsSync(), isTrue);
    expect(_cached, hasLength(1));
  });

  test('beyond the cap the least recently used attachment goes', () async {
    // Room for two encrypted 60-byte files, not three.
    await _start(cap: 2 * (60 + AttachmentCache.overhead) + 10);
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    final b = gmail.attach('m1', 'b.pdf', _content('b'));
    final c = gmail.attach('m1', 'c.pdf', _content('c'));
    _ok(await _file(a));
    h.clock.advance(const Duration(minutes: 1));
    _ok(await _file(b));
    h.clock.advance(const Duration(minutes: 1));
    // a used again: b is now the least recent.
    _ok(await _file(a));
    h.clock.advance(const Duration(minutes: 1));
    _ok(await _file(c));
    expect(_cached, hasLength(2));

    gmail.goOffline();
    expect(await _file(a), isA<Ok<String>>());
    expect(await _file(c), isA<Ok<String>>());
    expect(await _file(b), isA<Err<String>>());
  });

  test(
    'an attachment bigger than the cap opens without entering the cache',
    () async {
      await _start(cap: 100);
      final big = gmail.attach(
        'm1',
        'grande.zip',
        _content('grande') + _content('x'),
      );
      final path = _ok(await _file(big));
      expect(h.fs.file(path).lengthSync(), 120);
      expect(_cached, isEmpty);
    },
  );

  test('a cancelled download leaves nothing in the cache', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    gmail.holdAttachment = Completer<void>();
    final cancel = Completer<void>();
    final r = _file(a, cancel: cancel.future);
    cancel.complete();
    expect(
      await r,
      isA<Err<String>>().having(
        (e) => e.failure,
        'failure',
        isA<CancelledFailure>(),
      ),
    );
    expect(_cached, isEmpty);
  });

  test(
    'downloads crossing the cap together all open, and the cache fits',
    () async {
      await _start(cap: 2 * (60 + AttachmentCache.overhead) + 10);
      final all = [
        for (final n in ['a', 'b', 'c', 'd', 'e', 'f'])
          gmail.attach('m1', '$n.pdf', _content(n)),
      ];
      _ok(await _file(all[0]));
      _ok(await _file(all[1]));
      final results = await Future.wait([
        for (final a in all.skip(2)) _file(a),
      ]);
      expect(results, everyElement(isA<Ok<String>>()));
      expect(_cached, hasLength(2));
    },
  );

  test('Annulla after the Provider\'s last abortable moment still drops the result', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    final hold = gmail.holdAttachment = Completer<void>();
    final cancel = Completer<void>();
    final r = _file(a, cancel: cancel.future);
    // The Provider answers, then the user cancels before the cache gets the answer.
    hold.complete();
    cancel.complete();
    expect(
      await r,
      isA<Err<String>>().having(
        (e) => e.failure,
        'failure',
        isA<CancelledFailure>(),
      ),
    );
    expect(_cached, isEmpty);
  });

  test('a keychain error fails one try, not the ones after it', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    h.keychain.failure = Exception('keychain locked');
    expect(
      await _file(a),
      isA<Err<String>>().having(
        (e) => e.failure,
        'failure',
        isA<UnexpectedFailure>(),
      ),
    );
    h.keychain.failure = null;
    expect(await _file(a), isA<Ok<String>>());
  });

  test('a file half written by a crash is gone at the next launch; a recent one, maybe another isolate\'s write, stays', () async {
    await _start();
    _cacheDir.childFile('old.part')
      ..writeAsBytesSync([1, 2, 3])
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    _cacheDir.childFile('new.part').writeAsBytesSync([1, 2, 3]);
    await AttachmentStorage.open(
      _cacheDir,
      h.fs.directory('/tmp/postino-attachments'),
    );
    expect(_cached.map((f) => f.basename), ['new.part']);
  });

  for (final (step, where) in [
    ('the cache file is written', '.part'),
    ('the temporary copy is written', '/tmp/postino-attachments/'),
  ]) {
    test('Annulla while $step leaves nothing behind', () async {
      await _start();
      final a = gmail.attach('m1', 'a.pdf', _content('a'));
      final cancel = Completer<void>();
      h.onFileOp = (path, op) {
        if (op == FileSystemOp.write &&
            path.contains(where) &&
            !cancel.isCompleted) {
          cancel.complete();
        }
      };
      expect(
        await _file(a, cancel: cancel.future),
        isA<Err<String>>().having(
          (e) => e.failure,
          'failure',
          isA<CancelledFailure>(),
        ),
      );
      expect(_cached, isEmpty);
      expect(h.fs.directory('/tmp/postino-attachments').listSync(), isEmpty);
    });
  }

  test(
    'a temporary copy that cannot be written is a failure, and leaves nothing',
    () async {
      await _start();
      final a = gmail.attach('m1', 'a.pdf', _content('a'));
      h.onFileOp = (path, op) {
        if (op == FileSystemOp.write && path.startsWith('/tmp/')) {
          throw const FileSystemException('disk full');
        }
      };
      expect(
        await _file(a),
        isA<Err<String>>().having(
          (e) => e.failure,
          'failure',
          isA<UnexpectedFailure>(),
        ),
      );
      h.onFileOp = null;
      expect(h.fs.directory('/tmp/postino-attachments').listSync(), isEmpty);
    },
  );

  test('an eviction that fails does not block the ones after it', () async {
    await _start(cap: 2 * (60 + AttachmentCache.overhead) + 10);
    final all = [
      for (final n in ['a', 'b', 'c', 'd'])
        gmail.attach('m1', '$n.pdf', _content(n)),
    ];
    _ok(await _file(all[0]));
    h.clock.advance(const Duration(minutes: 1));
    _ok(await _file(all[1]));
    h.clock.advance(const Duration(minutes: 1));
    var failOnce = true;
    h.onFileOp = (path, op) {
      if (op == FileSystemOp.delete &&
          path.startsWith('/support/') &&
          !path.endsWith('.part') &&
          failOnce) {
        failOnce = false;
        throw const FileSystemException('busy');
      }
    };
    expect(await _file(all[2]), isA<Err<String>>());
    h.clock.advance(const Duration(minutes: 1));
    expect(await _file(all[3]), isA<Ok<String>>());
    expect(_cached, hasLength(2));
  });

  test('two downloads of the same attachment at once both open', () async {
    await _start();
    final a = gmail.attach('m1', 'a.pdf', _content('a'));
    final both = await Future.wait([_file(a), _file(a)]);
    expect(both, everyElement(isA<Ok<String>>()));
    expect(_cached, hasLength(1));
  });

  test('an attachment name never leaves its folder', () {
    expect(safeFileName('CON.txt'), '_CON.txt');
    expect(safeFileName('lpt1'), '_lpt1');
    expect(safeFileName('console.txt'), 'console.txt');
    expect(safeFileName('report. . '), 'report');
    // Cut at 150 bytes, no trailing dot or space left by the cut.
    expect(safeFileName('${'a' * 149} xxxxx'), 'a' * 149);
    // Bytes, not characters: 100 CJK characters are 300 bytes, over the file system's 255.
    final cjk = safeFileName('${'漢' * 100}.pdf');
    expect(cjk, '${'漢' * 48}.pdf');
    expect(utf8.encode(cjk).length, lessThanOrEqualTo(maxFileNameBytes));
    // 142 + 4 bytes fit the 146 left by «.txt»: the first emoji stays whole, the second goes whole.
    final emoji = safeFileName('${'a' * 142}😀😀.txt');
    expect(emoji, '${'a' * 142}😀.txt');
    expect(utf8.encode(emoji).length, maxFileNameBytes);
    expect(safeFileName('a?b*c<d>|"e.pdf'), 'a_b_c_d___e.pdf');
    final long = safeFileName('${'x' * 300}.pdf');
    expect(long, hasLength(maxFileNameBytes));
    expect(long, endsWith('x.pdf'));
    expect(safeFileName('../../etc/passwd'), '.._.._etc_passwd');
    expect(safeFileName('..'), 'allegato');
    expect(safeFileName('  '), 'allegato');
    expect(safeFileName('Fattura 03.pdf'), 'Fattura 03.pdf');
  });

  test('invisible and bidi characters go, C1 controls become _ (#75)', () {
    // U+202E right-to-left override: «fattura\u202Efdp.exe» is displayed as «fatturaexe.pdf».
    expect(safeFileName('fattura\u202Efdp.exe'), 'fatturafdp.exe');
    expect(
      safeFileName('a\u200Eb\u200Fc\u2066d\u2069e\uFEFFf\u200Bg.pdf'),
      'abcdefg.pdf',
    );
    expect(safeFileName('a\u007Fb.pdf'), 'a_b.pdf');
  });
}
