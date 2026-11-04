import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/file_name.dart';
import '../../../core/domain/file_size.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/mailbox.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/result.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/draft_html.dart';

/// Writing a Bozza (#35): the Account it leaves from, A, Cc, Ccn, Oggetto and the rich editor. Opens the
/// Bozza [messageId] (ours or another client's), or starts an empty one with that Message-ID; every edit
/// saves it through [MailSync.saveDraft], leaving it (any way) syncs it at once. Invia (#36, Cmd/Ctrl+Enter too)
/// queues it through [MailSync.send] and calls [onQueued]: the caller closes the composer and shows Annulla invio.
/// Routing is the caller's ([onClose], [onQueued]).
class ComposerView extends StatefulWidget {
  const ComposerView({
    super.key,
    required this.accountId,
    required this.messageId,
    required this.onClose,
    required this.onQueued,
  });

  final String accountId;
  final String messageId;
  final VoidCallback onClose;

  /// [until]: the end of the Annulla invio window, as the engine computed it.
  final void Function(String accountId, String messageId, DateTime until) onQueued;

  @override
  State<ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<ComposerView> with AccountsSignal {
  final _sync = GetIt.I<MailSync>();
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _bcc = TextEditingController();
  final _subject = TextEditingController();
  final _editorFocus = FocusNode(debugLabel: 'Editor');
  final _subs = <StreamSubscription<Object?>>[];

  /// Null until the Bozza is opened; [_failed] when it could not be.
  QuillController? _controller;

  /// The Bozza as opened: a reply's In-Reply-To, References and Conversazione and a forward's
  /// attachments (#37) are not in the fields, so every save copies them from here.
  OutgoingMessage? _opened;
  bool _failed = false;
  bool _withAttachments = false;
  bool _isReply = false;
  List<Account> get _accounts => accounts.value.value ?? const [];

  /// The Account the Bozza leaves from: changeable until the first save.
  // ponytail: moving a Bozza between Accounts comes if needed.
  late String _from = widget.accountId;
  bool _saved = false;

  /// Why the last Invia was refused (no recipient, too big, failed); cleared by the next edit.
  String? _sendError;

  @override
  void initState() {
    super.initState();
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
        _opened = value;
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

  /// The message as written, or null before the Bozza is open (or its Account gone).
  OutgoingMessage? _message() {
    final c = _controller;
    final address = _accounts.where((a) => a.id == _from).firstOrNull?.address;
    if (c == null || address == null) return null;
    List<String> addresses(String s) => parseMailboxes(s).map(formatMailbox).toList();
    return OutgoingMessage(
      messageId: widget.messageId,
      from: address,
      to: addresses(_to.text),
      cc: addresses(_cc.text),
      bcc: addresses(_bcc.text),
      subject: _subject.text,
      body: deltaToHtml(c.document.toDelta().toJson()),
      inReplyTo: _opened?.inReplyTo,
      references: _opened?.references ?? const [],
      conversationId: _opened?.conversationId,
      attachments: _opened?.attachments ?? const [],
    );
  }

  void _save() {
    final c = _controller;
    final m = _message();
    // While the engine prepares the message the queued snapshot is fixed: an edit now would be lost with the Bozza.
    if (c == null || m == null || _sending) return;
    if (_sendError != null) setState(() => _sendError = null);
    final fields = [_to.text, _cc.text, _bcc.text, _subject.text];
    // Nothing written yet: no Bozza. Once saved, emptying it is an edit like any other.
    if (!_saved && fields.every((s) => s.trim().isEmpty) && c.document.isEmpty()) {
      return;
    }
    if (!_saved) setState(() => _saved = true);
    unawaited(_sync.saveDraft(_from, m));
  }

  // Set while the engine prepares the message: a second Invia would queue it twice.
  bool _sending = false;

  Future<void> _send() async {
    final t = context.t.composizione;
    final m = _message();
    if (m == null) return;
    if ([...m.to, ...m.cc, ...m.bcc].isEmpty) {
      return setState(() => _sendError = t.noRecipient);
    }
    if (_sending) return;
    setState(() => _sending = true);
    final r = await _sync.send(_from, m);
    // The composer may be gone (Chiudi while preparing): onQueued belongs to the layout, which guards itself.
    if (r case Ok(:final value)) {
      widget.onQueued(_from, widget.messageId, value);
    }
    if (!mounted) return;
    setState(() => _sending = false);
    switch (r) {
      case Ok():
        break;
      case Err(failure: OfflineFailure()):
        setState(() => _sendError = t.offlineAttachments);
      case Err(failure: SizeLimitFailure(:final limitBytes)):
        setState(() => _sendError = t.tooLarge(mb: limitBytes ~/ (1024 * 1024)));
      case Err():
        setState(() => _sendError = t.sendFailed);
    }
  }

  @override
  void dispose() {
    // Leaving the composition, whichever way (Chiudi, Esc, indietro, another view): the Bozza syncs now.
    unawaited(_sync.flushDrafts(_from));
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _controller?.dispose();
    _editorFocus.dispose();
    for (final c in [_to, _cc, _bcc, _subject]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(builder: _content);

  Widget _content(BuildContext context) {
    final t = context.t.composizione;
    final controller = _controller;
    final narrow = MediaQuery.sizeOf(context).width < PostinoSize.breakpointListDetail;
    PostinoSenderOption option(Account a) =>
        (id: a.id, mark: (color: PostinoAccountColor.values[a.color], initial: a.initial), address: a.address);
    final senders = _accounts.map(option).toList();
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return PostinoSinglePaneLayout(
      appBar: PostinoAppBar(
        title: t.title,
        onBack: narrow ? widget.onClose : null,
        actions: [
          if (!_failed) PostinoIconButton(icon: PostinoIcons.send, label: t.send, onPressed: _sending ? null : _send),
          PostinoIconButton(icon: PostinoIcons.close, label: t.close, onPressed: widget.onClose),
        ],
      ),
      banners: [
        if (_sendError case final e?)
          PostinoBanner(key: const ValueKey('send-error'), tone: PostinoBannerTone.danger, title: e),
      ],
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
          // Cmd/Ctrl+Enter sends from any field or the editor (ADR 0014); the Posta registry skips text fields.
          : CallbackShortcuts(
              bindings: {SingleActivator(LogicalKeyboardKey.enter, meta: mac, control: !mac): _send},
              child: AbsorbPointer(
                absorbing: _sending,
                child: ExcludeFocus(
                  excluding: _sending,
                  child: PostinoComposerLayout(
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
                          keyboardType: c == _subject ? TextInputType.text : TextInputType.emailAddress,
                          onChanged: (_) => _save(),
                        ),
                      // The attachments a forward carries over (#37), read-only.
                      // ponytail: adding and removing attachments is #75.
                      if (_opened?.attachments case final atts? when atts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: PostinoSpacing.s3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: PostinoSpacing.s3,
                            children: [
                              Text(
                                t.forwardedAttachments,
                                style: PostinoText.label.copyWith(color: context.pc.inkMuted),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: PostinoSpacing.s2,
                                  runSpacing: PostinoSpacing.s2,
                                  children: [
                                    for (final a in atts)
                                      PostinoAttachmentChip(
                                        key: ValueKey('draft-attachment-${a.attachment.id}'),
                                        // safeFileName: un override bidi non deve falsare l'estensione mostrata.
                                        name: safeFileName(a.attachment.name),
                                        size: fileSize(a.attachment.size, Localizations.localeOf(context).languageCode),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                ),
              ),
            ),
    );
  }
}
