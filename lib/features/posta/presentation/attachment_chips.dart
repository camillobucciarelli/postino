import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/file_name.dart';
import '../../../core/domain/file_size.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'attachment_actions.dart';

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

/// The chips of [message]'s attachments, with their download, failure and actions from [actions].
List<PostinoAttachmentChip> attachmentChips(
  AttachmentActions actions,
  Message message,
  MessageBody? body,
  Translations$conversazione$it t,
  String locale,
) => [
  for (final a in body?.attachments ?? const <Attachment>[])
    if ((actions.download(message.id, a.id), _name(a, t)) case (
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
            : () => actions.start(message.id, a, name),
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
        error: switch (actions.failure(message.id, a.id)) {
          null => null,
          (failure: OfflineFailure(), save: _, saving: _) =>
            t.attachmentOffline,
          (failure: _, save: _, saving: true) => t.attachmentSaveFailed,
          _ => t.attachmentFailed,
        },
        retryLabel: t.retry,
        onRetry: () => actions.start(
          message.id,
          a,
          name,
          save:
              isExecutableName(name) ||
              (actions.failure(message.id, a.id)?.save ?? false),
        ),
        moreLabel: t.attachmentMore,
        saveLabel: t.attachmentSave,
        onSave: GetIt.I<FileSaver>().available
            ? () => actions.start(message.id, a, name, save: true)
            : null,
      ),
];
