import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

void main() {
  test('light and dark themes map the brand token to primary', () {
    expect(PostinoTheme.light().colorScheme.primary, PostinoColors.light.brand);
    expect(PostinoTheme.dark().colorScheme.primary, PostinoColors.dark.brand);
    expect(PostinoTheme.dark().brightness, Brightness.dark);
  });
}
