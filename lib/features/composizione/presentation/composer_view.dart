import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/mailbox.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/draft_html.dart';

/// Writing a Bozza (#35): the Account it leaves from, A, Cc, Ccn, Oggetto and the rich editor. Opens the
/// Bozza [messageId] (ours or another client's), or starts an empty one with that Message-ID; every edit
/// saves it through [MailSync.saveDraft], leaving it (any way) syncs it at once. Routing is the caller's ([onClose]).
class ComposerView extends StatefulWidget {
  const ComposerView({
    super.key,
    required this.accountId,
    required this.messageId,
    required this.onClose,
  });

  final String accountId;
  final String messageId;
  final VoidCallback onClose;

  @override
  State<ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<ComposerView> {
  final _sync = GetIt.I<MailSync>();
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _bcc = TextEditingController();
  final _subject = TextEditingController();
  final _editorFocus = FocusNode(debugLabel: 'Editor');
  final _subs = <StreamSubscription<Object?>>[];

  /// Null until the Bozza is opened; [_failed] when it could not be.
  QuillController? _controller;
  bool _failed = false;
  bool _withAttachments = false;
  bool _isReply = false;
  List<Account> _accounts = const [];

  /// The Account the Bozza leaves from: changeable until the first save.
  // ponytail: moving a Bozza between Accounts comes if needed.
  late String _from = widget.accountId;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _subs.add(
      GetIt.I<AccountsRepository>().watchAccounts().listen(
        (a) => setState(() => _accounts = a),
      ),
    );
    unawaited(_open());
  }

  Future<void> _open() async {
    final r = await _sync.openDraft(widget.accountId, widget.messageId);
    if (!mounted) return;
    var ops = htmlToDelta('');
    switch (r) {
      case Ok(:final value):
        _to.text = value.to.join(', ');
        _cc.text = value.cc.join(', ');
        _bcc.text = value.bcc.join(', ');
        _subject.text = value.subject;
        ops = htmlToDelta(value.body);
        _saved = true;
      // A new Bozza: its Message-ID is already ours.
      case Err(failure: NotFoundFailure()):
        break;
      case Err(failure: DraftWithAttachmentsFailure()):
        return setState(() => _failed = _withAttachments = true);
      case Err(failure: DraftReplyFailure()):
        return setState(() => _failed = _isReply = true);
      // ponytail: any other failure (offline, body not downloadable) reads as «Bozza non trovata»; a Riprova if it bites.
      case Err():
        return setState(() => _failed = true);
    }
    final controller = QuillController(
      document: Document.fromDelta(Delta.fromJson(ops)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _subs.add(controller.changes.listen((_) => _save()));
    setState(() => _controller = controller);
  }

  void _save() {
    final c = _controller;
    final address = _accounts.where((a) => a.id == _from).firstOrNull?.address;
    if (c == null || address == null) return;
    final fields = [_to.text, _cc.text, _bcc.text, _subject.text];
    // Nothing written yet: no Bozza. Once saved, emptying it is an edit like any other.
    if (!_saved &&
        fields.every((s) => s.trim().isEmpty) &&
        c.document.isEmpty()) {
      return;
    }
    if (!_saved) setState(() => _saved = true);
    List<String> addresses(String s) =>
        parseMailboxes(s).map(formatMailbox).toList();
    unawaited(
      _sync.saveDraft(
        _from,
        OutgoingMessage(
          messageId: widget.messageId,
          from: address,
          to: addresses(_to.text),
          cc: addresses(_cc.text),
          bcc: addresses(_bcc.text),
          subject: _subject.text,
          body: deltaToHtml(c.document.toDelta().toJson()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Leaving the composition, whichever way (Chiudi, Esc, indietro, another view): the Bozza syncs now.
    unawaited(_sync.flushDrafts(_from));
    for (final s in _subs) {
      s.cancel();
    }
    _controller?.dispose();
    _editorFocus.dispose();
    for (final c in [_to, _cc, _bcc, _subject]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.composizione;
    final controller = _controller;
    final narrow =
        MediaQuery.sizeOf(context).width < PostinoSize.breakpointListDetail;
    PostinoSenderOption option(Account a) => (
      id: a.id,
      mark: (color: PostinoAccountColor.values[a.color], initial: a.initial),
      address: a.address,
    );
    final senders = _accounts.map(option).toList();
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(
        title: t.title,
        onBack: narrow ? widget.onClose : null,
        actions: [
          PostinoIconButton(
            icon: PostinoIcons.close,
            label: t.close,
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: _failed
          ? PostinoEmptyState(
              title: _isReply
                  ? t.draftReply
                  : _withAttachments
                  ? t.draftWithAttachments
                  : t.draftNotFound,
            )
          : controller == null || senders.every((s) => s.id != _from)
          ? const SizedBox.shrink()
          : PostinoComposerLayout(
              sender: PostinoSenderPicker(
                label: t.from,
                options: senders,
                selectedId: _from,
                enabled: !_saved,
                onSelected: (id) => setState(() => _from = id),
              ),
              fields: [
                for (final (label, c, first) in [
                  (t.to, _to, true),
                  (t.cc, _cc, false),
                  (t.bcc, _bcc, false),
                  (t.subject, _subject, false),
                ])
                  PostinoComposerField(
                    label: label,
                    controller: c,
                    autofocus: first && !_saved,
                    keyboardType: c == _subject
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    onChanged: (_) => _save(),
                  ),
              ],
              editor: PostinoRichEditor(
                controller: controller,
                focusNode: _editorFocus,
                label: t.editor,
                placeholder: t.body,
                labels: PostinoFormatLabels(
                  bold: t.bold,
                  italic: t.italic,
                  underline: t.underline,
                  strikethrough: t.strikethrough,
                  link: t.link,
                  bulletList: t.bulletList,
                  numberedList: t.numberedList,
                  linkUrl: t.linkUrl,
                  insert: t.insert,
                  cancel: t.cancel,
                ),
              ),
            ),
    );
  }
}
