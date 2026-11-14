// #264: mittente e ora pesano 600 se non letti e 400 se letti (il «non letto» per VoiceOver viene da message_list, non dal peso).
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void main() {
  for (final unread in [true, false]) {
    testWidgets('riga ${unread ? 'non letta' : 'letta'}: peso di mittente e ora', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PostinoTheme.light(),
          home: Scaffold(
            body: PostinoMessageTile(
              sender: 'Bruno',
              subject: 'Preventivo',
              preview: 'Ciao',
              time: '09:42',
              unread: unread,
              starred: false,
              semanticLabel: unread ? 'Non letto, Bruno' : 'Bruno',
            ),
          ),
        ),
      );
      final expected = unread ? FontWeight.w600 : FontWeight.w400;
      expect(tester.widget<Text>(find.text('Bruno')).style!.fontWeight, expected);
      expect(tester.widget<Text>(find.text('09:42')).style!.fontWeight, expected);
    });
  }
}
