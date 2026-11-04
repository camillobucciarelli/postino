/// Stands for a shown address that is not a plain hostname: it matches no real host, so the link warns.
const malformedHost = '\u0000malformed';

/// An explicit address, wherever it sits in the label (after an emoji, an arrow, a letter, a colon...): a scheme and
/// `://`, or `www.`; then the host, up to a delimiter; then, if it follows a `/`, `?`, `#` or `:`, the rest of that URL (path, query), which is not read; anything else after
/// the host stays in the text and is read as bare domains (`paypal.com→evil.io`).
final _explicit = RegExp(
  r"(?:[a-z][a-z0-9+.\-]{0,31}://|www\.)(\[[0-9a-f:.]*\]|[\p{L}\p{N}\p{M}_@.-]*)(?:[/?#:][^\s,;|<>\x22'()]*)?",
  caseSensitive: false,
  unicode: true,
);

/// A run of hostname characters with a dot between them: any bare domain in the text.
final _dotted = RegExp(r'[\p{L}\p{N}\p{M}_-]+(?:\.[\p{L}\p{N}\p{M}_-]+)+', unicode: true);

final _hostname = RegExp(r'^[\p{L}\p{N}\p{M}_-]+(\.[\p{L}\p{N}\p{M}_-]+)*$', unicode: true);
final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// File extensions that are not top-level domains: `report.pdf` is a file, not a site.
const _files = {
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', 'odt', 'json', 'xml', //
  'png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'mp3', 'mp4', 'html', 'htm', 'php', 'js', 'css',
};

/// Whether [host] ends in something that can be a top-level domain: letters, two or more, not a file extension.
bool _tld(String host) {
  final tld = host.split('.').last;
  return tld.length >= 2 && !RegExp(r'^[\d_-]+$').hasMatch(tld) && !_files.contains(tld.toLowerCase());
}

/// The hosts a link's visible `original` claims to go to, wherever they sit in it. Explicit addresses (`scheme://host`,
/// `www.host`) always count; one whose host is not a clean hostname counts as [malformedHost] (the link warns).
/// Outside them, every bare domain (`label.label`, a top-level domain of letters) counts too. Trailing dots are
/// ignored. Versions (`3.14`, `1.2.3`) and file names (`report.pdf`) are not domains.
List<String> displayedHosts(String original) {
  // A label this long is not a label: it is read as malformed (warns) instead of scanned.
  if (original.length > 2048) return const [malformedHost];
  // Invisible characters would split a domain for the scan but not for the eye; ideographic dots are dots.
  final text = original
      .replaceAll(RegExp(r'\p{Cf}', unicode: true), '')
      .replaceAll(RegExp('[\u3002\uFF0E\uFF61]'), '.');
  final hosts = <String>[];
  for (final m in _explicit.allMatches(text)) {
    final raw = m[1]!;
    if (raw.startsWith('[')) {
      hosts.add(raw.substring(1, raw.length - 1).toLowerCase());
      continue;
    }
    final host = raw.split('@').last.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
    if (_ipv4.hasMatch(host) || (_hostname.hasMatch(host) && host.contains('.') && _tld(host))) {
      hosts.add(host);
    } else {
      hosts.add(malformedHost);
    }
  }
  for (final m in _dotted.allMatches(text.replaceAll(_explicit, ' '))) {
    if (_tld(m[0]!)) hosts.add(m[0]!.toLowerCase());
  }
  return hosts;
}
