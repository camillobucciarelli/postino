import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/attachment_repository.dart';
import '../../../core/domain/file_name.dart';
import '../../../core/domain/file_size.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The attachments of an open Conversazione (#34): a tap downloads one (unless cached) and opens it in the
/// system's app, its menu saves it; an executable is only saved (#75). Holds the downloads running and the
/// last failures; [onChanged] rebuilds the view, never after [dispose].
class AttachmentActions {
  AttachmentActions(this.accountId, this.onChanged);
  final String accountId;
  final VoidCallback onChanged;
  bool _disposed = false;

  /// By (message id, attachment id): the downloads running, with their progress and their Annulla,
  /// and why the last one failed.
  final _downloads =
      <(String, String), ({double done, Completer<void> cancel})>{};

  /// The failure, whether it was a Save As (Riprova repeats the same action) and whether the save itself
  /// failed, not the download before it.
  final _failed =
      <(String, String), ({Failure failure, bool save, bool saving})>{};

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    onChanged();
  }

  /// Cancels the downloads running: nothing is opened or saved after.
  void dispose() {
    _disposed = true;
    for (final d in _downloads.values) {
      if (!d.cancel.isCompleted) d.cancel.complete();
    }
  }

  /// Downloads (unless cached) then opens it in the system's app, or with [save] offers Save As.
  /// [name] is the one the chip shows: the opened copy and Save As carry it too.
  Future<void> _attachment(
    String messageId,
    Attachment attachment,
    String name, {
    bool save = false,
  }) async {
    final key = (messageId, attachment.id);
    if (_downloads.containsKey(key)) return;
    final cancel = Completer<void>();
    _update(() {
      _downloads[key] = (done: 0, cancel: cancel);
      _failed.remove(key);
    });
    Result<String> r = const Err(UnexpectedFailure('attachment'));
    try {
      r = await GetIt.I<AttachmentRepository>().file(
        accountId,
        messageId,
        Attachment(
          id: attachment.id,
          name: name,
          size: attachment.size,
          mimeType: attachment.mimeType,
        ),
        onProgress: (done) {
          if (_downloads.containsKey(key)) {
            _update(() => _downloads[key] = (done: done, cancel: cancel));
          }
        },
        cancel: cancel.future,
      );
    } finally {
      // Whatever happens, the chip leaves the download: never stuck on it.
      _update(() {
        _downloads.remove(key);
        if (r case Err(:final failure) when failure is! CancelledFailure) {
          _failed[key] = (failure: failure, save: save, saving: false);
        }
      });
    }
    if (_disposed) return;
    if (r case Ok(value: final path)) {
      if (!save) return GetIt.I<LinkOpener>().open(Uri.file(path));
      try {
        await GetIt.I<FileSaver>().save(path, name);
      } on Exception catch (e, s) {
        // A full disk, a folder it may not write to: said on the attachment, Riprova saves again.
        _update(
          () => _failed[key] = (
            failure: UnexpectedFailure(e, s),
            save: true,
            saving: true,
          ),
        );
      }
    }
  }

  /// The attachment's name, or «Allegato senza nome» when the message gives none.
  /// The same name everywhere (chip, opened copy, Save As), with an extension from its type when it has none,
  /// so it opens in the right app (open_filex picks the app by extension only); [safeFileName] strips bidi
  /// and invisible characters, so the chip shows the name the file gets (#75).
  String _name(Attachment a, Translations$conversazione$it t) =>
      safeFileName(switch (a.name) {
        '' => '${t.attachmentUntitled}${a.fallbackExtension}',
        final n when !n.contains('.') => '$n${a.fallbackExtension}',
        final n => n,
      });

  /// The chips of [message]'s attachments, with their download, failure and actions.
  List<PostinoAttachmentChip> chips(
    Message message,
    MessageBody? body,
    Translations$conversazione$it t,
    String locale,
  ) => [
    for (final a in body?.attachments ?? const <Attachment>[])
      if ((_downloads[(message.id, a.id)], _name(a, t)) case (
        final d,
        final name,
      ))
        PostinoAttachmentChip(
          key: ValueKey('attachment-${message.id}-${a.id}'),
          name: name,
          size: fileSize(a.size, locale),
          openLabel: t.attachmentOpen,
          onOpen: isExecutableName(name)
              ? null
              : () => _attachment(message.id, a, name),
          warning: isExecutableName(name) ? t.attachmentExecutable : null,
          progress: d?.done,
          progressLabel: d == null
              ? null
              : t.attachmentDownloading(percent: (d.done * 100).round()),
          cancelLabel: t.attachmentCancel,
          onCancel: () {
            if (d case (done: _, :final cancel) when !cancel.isCompleted) {
              cancel.complete();
            }
          },
          error: switch (_failed[(message.id, a.id)]) {
            null => null,
            (failure: OfflineFailure(), save: _, saving: _) =>
              t.attachmentOffline,
            (failure: _, save: _, saving: true) => t.attachmentSaveFailed,
            _ => t.attachmentFailed,
          },
          retryLabel: t.retry,
          onRetry: () => _attachment(
            message.id,
            a,
            name,
            save:
                isExecutableName(name) ||
                (_failed[(message.id, a.id)]?.save ?? false),
          ),
          moreLabel: t.attachmentMore,
          saveLabel: t.attachmentSave,
          onSave: GetIt.I<FileSaver>().available
              ? () => _attachment(message.id, a, name, save: true)
              : null,
        ),
  ];
}
