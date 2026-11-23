// The twin of shortcut_labels.dart: the keys of a shortcut as the tooltips say them (#369).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/presentation/posta_shortcuts.dart';
import 'package:postino/features/posta/presentation/shortcut_labels.dart';
import 'package:postino/i18n/strings.g.dart';

Future<Map<PostaAction, String?>> _labels(WidgetTester tester, TargetPlatform platform) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  LocaleSettings.setLocaleSync(AppLocale.it);
  late Map<PostaAction, String?> labels;
  await tester.pumpWidget(
    TranslationProvider(
      child: Builder(
        builder: (context) {
          labels = {for (final a in PostaAction.values) a: shortcutLabel(context, a)};
          return const SizedBox();
        },
      ),
    ),
  );
  return labels;
}

void main() {
  testWidgets('macOS: the letter, the character, ⇧ and ⌘ before it', (tester) async {
    final l = await _labels(tester, TargetPlatform.macOS);
    expect(l[PostaAction.reply], 'R');
    expect(l[PostaAction.delete], '#');
    expect(l[PostaAction.markUnread], '⇧U');
    expect(l[PostaAction.refresh], '⌘R');
    expect(l[PostaAction.next], 'J', reason: 'the arrows are the list\'s only');
  });

  testWidgets('elsewhere: Maiusc+ and Ctrl+ spelled out', (tester) async {
    final l = await _labels(tester, TargetPlatform.android);
    expect(l[PostaAction.archive], 'E');
    expect(l[PostaAction.markRead], 'Maiusc+I');
    expect(l[PostaAction.toggleSidebar], 'Ctrl+B');
  });
}
