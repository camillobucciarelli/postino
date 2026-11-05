import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:injectable/injectable.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/error_log.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/report_sharer.dart';
import 'problem_report_config.dart';

/// Segnalazione di un problema (#117), on top of the error log (#116). With an Account it saves a Bozza to the
/// author, from the first Account by position, with the log in its body: the user reads it in the composer and
/// decides whether to send it. Without one it shares the log file through the system share sheet.
@injectable
class ReportProblemUseCase(
  final ErrorLog _log,
  final AccountsRepository _accounts,
  final MailSync _sync,
  final ReportSharer _sharer,
) {
  /// Lega il log al percorso di invio.
  this;

  /// The most log a Bozza carries, the latest entries (the whole log still goes in the shared file). The composer
  /// is a rich editor: half a megabyte of text would freeze it.
  // ponytail: a tail in the body, not an attachment: the composer has no way to attach a new file yet.
  static const maxBodyChars = 48 * 1024;

  static const _escape = HtmlEscape(HtmlEscapeMode.element);

  /// Starts the report: [subject] and [intro] are the texts of the Bozza (the UI's, translated). Returns the
  /// (Account, Message-ID) of the Bozza to open in the composer, or null when the log was shared instead.
  Future<(String, String)?> start({required String subject, required String intro}) async {
    final log = await _log.read();
    final accounts = await _accounts.watchAccounts().first;
    if (accounts.isEmpty) {
      await _sharer.share(text: log, name: problemReportFileName, subject: subject);
      return null;
    }
    final account = accounts.first;
    final messageId = newMessageId(account.address);
    await _sync.saveDraft(
      account.id,
      OutgoingMessage(
        messageId: messageId,
        from: account.address,
        to: const [problemReportAddress],
        subject: subject,
        body: _body(intro, log),
      ),
    );
    return (account.id, messageId);
  }

  static String _body(String intro, String log) {
    // Cut at a line start: no half entry, and never between the two halves of a surrogate pair.
    final cut = log.length - maxBodyChars;
    final newline = cut <= 0 ? 0 : log.indexOf('\n', cut);
    // No newline left: cut anywhere, but not between the halves of a surrogate pair.
    final lone = newline < 0 && cut < log.length && (log.codeUnitAt(cut) & 0xFC00) == 0xDC00;
    final start = newline < 0 ? (lone ? cut + 1 : cut) : newline + 1;
    final tail = cut <= 0 ? log : '…${log.substring(start).trimLeft()}';
    // One paragraph per line: the composer's parser drops the line breaks of a <pre>.
    final lines = [intro, ...tail.split('\n').where((l) => l.trim().isNotEmpty)];
    return [for (final l in lines) '<p>${_escape.convert(l)}</p>'].join();
  }
}
