// ReplyDraftUseCase (#88): the message answered, its body downloaded when missing, Inoltra unavailable
// without the attachments, and the Bozza saved only by the second step.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/features/posta/domain/reply_draft_use_case.dart';
import 'package:postino/features/posta/domain/reply_kind.dart';
import 'package:postino/features/posta/domain/reply_source.dart';

import '../../support/fake_mail_provider.dart' show msg;

const _account = Account(id: 'a1', address: 'a1@example.com', provider: ProviderKind.gmail, color: 0, position: 0);

/// fetchBody answers [fetched] (or fails without it); saveDraft records the Bozza.
class _Sync(final _Inbox inbox, {final MessageBody? fetched}) extends Fake implements MailSync {
  final fetches = <String>[];
  final drafts = <OutgoingMessage>[];

  @override
  Future<Result<void>> fetchBody(String accountId, String messageId) async {
    fetches.add(messageId);
    final b = fetched;
    if (b == null) return const Err(OfflineFailure());
    inbox.rows = [for (final r in inbox.rows) r.message.id == messageId ? (message: r.message, body: b) : r];
    return const Ok(null);
  }

  @override
  Future<void> saveDraft(String accountId, OutgoingMessage draft) async => drafts.add(draft);
}

class _Inbox(var List<ConversationMessage> rows) extends Fake implements InboxRepository {
  @override
  Stream<List<ConversationMessage>> watchConversation(String accountId, String conversationId) => Stream.value(rows);
}

const _pdf = Attachment(id: 'p', name: 'a.pdf', size: 10);

List<ConversationMessage> _thread({MessageBody? lastBody}) => [
  (
    message: msg(
      'm1',
      conversationId: 't',
      from: 'bruno@example.com',
      to: ['a1@example.com', 'carla@example.com'],
      subject: 'Cena',
    ),
    body: const MessageBody('Venerdì?', BodyKind.testo),
  ),
  (
    message: msg(
      'm2',
      conversationId: 't',
      to: ['a1@example.com', 'carla@example.com'],
      subject: 'Re: Cena',
      snippet: 'Alle 20',
    ),
    body: lastBody,
  ),
];

void main() {
  late _Inbox inbox;
  late _Sync sync;
  late ReplyDraftUseCase useCase;

  void given({MessageBody? lastBody, MessageBody? fetched}) {
    inbox = _Inbox(_thread(lastBody: lastBody));
    sync = _Sync(inbox, fetched: fetched);
    useCase = ReplyDraftUseCase(sync, inbox);
  }

  Future<ReplySource> source(ReplyKind kind, {String? messageId}) =>
      useCase.source('a1', 't', inbox.rows, kind, messageId: messageId);

  test('Rispondi answers the last message by default, quoting its body', () async {
    given(lastBody: const MessageBody('<p>Alle 20</p>', BodyKind.html));
    final s = await source(ReplyKind.reply);
    expect(s.message.id, 'm2');
    expect(sync.fetches, isEmpty);
    final id = await useCase.save(_account, s);
    final d = sync.drafts.single;
    expect(d.messageId, id);
    expect(d.to, ['ada@example.com']);
    expect(d.cc, isEmpty);
    expect(d.subject, 'Re: Cena');
    expect(d.inReplyTo, '<m2@example.com>');
    expect(d.body, contains('<p>Alle 20</p>'));
    expect(d.body, contains('ha scritto:'));
  });

  test('Rispondi a tutti answers everyone but the Account', () async {
    given(lastBody: const MessageBody('Alle 20', BodyKind.testo));
    await useCase.save(_account, await source(ReplyKind.replyAll, messageId: 'm1'));
    final d = sync.drafts.single;
    expect(d.to, ['bruno@example.com', 'carla@example.com']);
    expect(d.cc, isEmpty);
    expect(d.inReplyTo, '<m1@example.com>');
    expect(d.body, contains('Venerdì?'));
  });

  test('a missing body is downloaded first and read again', () async {
    given(fetched: const MessageBody('Porto il vino', BodyKind.testo));
    final s = await source(ReplyKind.reply);
    expect(sync.fetches, ['m2']);
    expect(s.body?.content, 'Porto il vino');
    await useCase.save(_account, s);
    expect(sync.drafts.single.body, contains('Porto il vino'));
  });

  test('without the body, Rispondi quotes the snippet', () async {
    given();
    await useCase.save(_account, await source(ReplyKind.reply));
    expect(sync.drafts.single.body, contains('Alle 20'));
  });

  test('Inoltra takes the attachments over, re-downloading a body without them', () async {
    given(
      lastBody: const MessageBody('Alle 20', BodyKind.testo, attachments: null),
      fetched: const MessageBody('Alle 20', BodyKind.testo, attachments: [_pdf]),
    );
    final s = await source(ReplyKind.forward);
    expect(sync.fetches, ['m2']);
    expect(s.unavailable, isFalse);
    await useCase.save(_account, s);
    final d = sync.drafts.single;
    expect(d.to, isEmpty);
    expect(d.subject, 'Fwd: Cena');
    expect(d.attachments.single.sourceMessageId, 'm2');
    expect(d.attachments.single.attachment.id, 'p');
  });

  test('Inoltra is unavailable when the attachments cannot be known', () async {
    given(lastBody: const MessageBody('Alle 20', BodyKind.testo, attachments: null));
    final s = await source(ReplyKind.forward);
    expect(s.unavailable, isTrue);
    expect(sync.drafts, isEmpty);
    // Rispondi needs no attachments.
    expect((await source(ReplyKind.reply)).unavailable, isFalse);
  });

  test('source alone saves no Bozza', () async {
    given(fetched: const MessageBody('Porto il vino', BodyKind.testo));
    await source(ReplyKind.reply);
    await source(ReplyKind.forward);
    expect(sync.drafts, isEmpty);
  });
}
