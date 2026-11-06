import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'html_text.dart';
import 'mailbox.dart';
import 'message.dart';

/// What a Bozza says, the part its Conflitto compares (#149): recipients, subject and HTML body.
class const DraftContent({
  /// Destinatari principali, `Name <address>` o indirizzo nudo.
  required final List<String> to,

  /// Oggetto.
  required final String subject,

  /// HTML.
  required final String body,

  /// Destinatari in copia.
  final List<String> cc = const [],

  /// Destinatari in copia nascosta.
  final List<String> bcc = const [],
}) extends Equatable {
  /// Crea il contenuto di una Bozza.
  this;

  /// The content of [d].
  factory DraftContent.of(OutgoingMessage d) =>
      DraftContent(to: d.to, cc: d.cc, bcc: d.bcc, subject: d.subject, body: d.body);

  /// The impronta (#149), the expected value of a Bozza: SHA-256 of the addresses (lowercase, in any order), the
  /// trimmed subject and the body's text without whitespace, so the same Bozza read back from the Provider (its MIME
  /// re-encoded, the HTML re-indented) matches what was uploaded.
  // ponytail: a formatting-only edit elsewhere (bold, a link) is no change; hash the HTML if that ever matters.
  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            _addresses(to),
            _addresses(cc),
            _addresses(bcc),
            subject.trim(),
            htmlText(body).replaceAll(RegExp(r'\s+'), ''),
          ]),
        ),
      )
      .toString();

  static List<String> _addresses(List<String> l) => [for (final m in l) parseMailbox(m).address.toLowerCase()]..sort();

  @override
  List<Object?> get props => [to, cc, bcc, subject, body];
}
