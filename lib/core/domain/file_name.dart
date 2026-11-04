import 'dart:convert';

/// Under every file system's 255 bytes per name and, being at most as many UTF-16 units, under Windows'
/// 260 characters for the whole path of the temporary copy (`…\Temp\postino-attachments\<folder>\<name>`).
const maxFileNameBytes = 150;

/// [name] as a file name on every desktop: no folders (a hostile `../../x` stays inside the temporary folder),
/// none of the characters Windows refuses nor its trailing dots and spaces, no invisible or bidi character
/// (`fattura\u202Efdp.exe` shows as «fatturaexe.pdf»: #75), no device name (`CON.txt`),
/// at most [maxFileNameBytes] of UTF-8 (file systems cap a name at 255 bytes, not characters) keeping the
/// extension and whole characters, never empty.
String safeFileName(String name) {
  var s = name
      .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]'), '')
      .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f-\x9f]'), '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (utf8.encode(s).length > maxFileNameBytes) {
    final dot = s.lastIndexOf('.');
    final ext = dot > 0 && s.length - dot <= 10 ? s.substring(dot) : '';
    final room = maxFileNameBytes - utf8.encode(ext).length;
    // Code point by code point, so a multi-byte character is kept whole or dropped.
    final kept = StringBuffer();
    var bytes = 0;
    for (final r in s.substring(0, s.length - ext.length).runes) {
      final n = String.fromCharCode(r);
      bytes += utf8.encode(n).length;
      if (bytes > room) break;
      kept.write(n);
    }
    s = '$kept$ext'.replaceAll(RegExp(r'[. ]+$'), '');
  }
  if (s.isEmpty) return 'allegato';
  final stem = s.split('.').first.trim().toUpperCase();
  return RegExp(r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$').hasMatch(stem) ? '_$s' : s;
}
