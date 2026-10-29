import '../../../core/domain/message.dart';

/// The body as plain text: HTML loses its tags, keeping line breaks and entities.
// ponytail: minimal reading only; the faithful HTML rendering (flutter_widget_from_html, ADR 0007) is #47.
String bodyText(MessageBody body) {
  if (body.kind == BodyKind.testo) return body.content.trim();
  final text = body.content
      .replaceAll(
        RegExp(
          r'<(head|style|script)\b[^>]*>[\s\S]*?</\1\s*>',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s*\n\s*'), ' ')
      .replaceAll(
        RegExp(
          r'<br\s*/?>|</(p|div|li|tr|h[1-6]|blockquote)\s*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAllMapped(
        RegExp(r'&(#x?[0-9a-fA-F]+|[a-z]+);'),
        (m) => _entity(m.group(1)!) ?? m.group(0)!,
      );
  return text
      .split('\n')
      .map((l) => l.trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String? _entity(String e) {
  if (e.startsWith('#')) {
    final code = e[1] == 'x' || e[1] == 'X'
        ? int.tryParse(e.substring(2), radix: 16)
        : int.tryParse(e.substring(1));
    return code == null ? null : String.fromCharCode(code);
  }
  return const {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
  }[e];
}
