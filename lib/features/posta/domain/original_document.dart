/// The faithful HTML of a message for «Vedi originale» (ADR 0007): the sender's HTML, untouched, under a
/// Content-Security-Policy that allows no script, no frame, no font and no stylesheet link. Images: only `data:`,
/// plus `https:`/`http:` when [allowRemote] (the same rules as the Conversazione: shown for the message or a Mittente fidato).
String originalDocument(String html, {required bool allowRemote}) {
  final img = allowRemote ? "data: https: http:" : 'data:';
  return '<meta http-equiv="Content-Security-Policy" '
      "content=\"default-src 'none'; img-src $img; style-src 'unsafe-inline'\">$html";
}
