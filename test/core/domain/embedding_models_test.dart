// Il modello di embedding per piattaforma e architettura (#135, ADR 0015).

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/embedding_models.dart';

void main() {
  for (final os in ['macos', 'ios', 'android']) {
    test('$os arm64 gets the .litertlm', () {
      expect(embeddingModelFor(os, 'arm64'), same(embeddingGemmaLiteRt));
    });
  }

  for (final (os, arch) in [
    ('macos', 'x64'),
    ('android', 'x64'),
    ('android', 'arm'),
    ('android', 'ia32'),
    ('ios', 'x64'),
    ('windows', 'x64'),
    ('windows', 'arm64'),
    ('linux', 'x64'),
    ('linux', 'arm64'),
    ('fuchsia', 'arm64'),
  ]) {
    test('$os $arch gets the GGUF', () {
      expect(embeddingModelFor(os, arch), same(embeddingGemmaGguf));
    });
  }

  test('the two formats have their own id, file and hash, pinned to a commit', () {
    expect(embeddingGemmaLiteRt.id, isNot(embeddingGemmaGguf.id));
    expect(embeddingGemmaLiteRt.fileName, isNot(embeddingGemmaGguf.fileName));
    for (final m in [embeddingGemmaLiteRt, embeddingGemmaGguf]) {
      expect(m.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(m.url.path, contains('/resolve/'));
      expect(m.url.pathSegments.reversed.skip(1).first, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(m.url.pathSegments.last, m.fileName);
      expect(m.sizeBytes, greaterThan(100 * 1000 * 1000));
    }
  });
}
