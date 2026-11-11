// Microsoft adapter: bodies, attachments and Conversazioni on the responses of test/fixtures/graph. No network.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:postino/core/data/microsoft/microsoft_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/graph_recorded.dart';

const _wellKnown = {'inbox', 'sentitems', 'drafts', 'deleteditems', 'junkemail', 'outbox'};

http.Response _route(http.Request r, String path) => switch (path.split('/')) {
  ['messages', 'msg-f1'] => graphFixture('body_f1'),
  ['messages', 'msg-f2'] => graphFixture('body_f2'),
  ['messages', 'msg-f3'] => graphFixture('body_f3'),
  ['messages', 'msg-f2', 'attachments'] => graphFixture('attachments_f2'),
  ['messages', 'msg-f2', 'attachments', 'att-4', r'$value'] => http.Response.bytes(const [], 200),
  ['messages', 'msg-f2', 'attachments', _, r'$value'] => http.Response.bytes(utf8.encode('ciao'), 200),
  ['messages'] => graphFixture('conversation_c1'),
  ['mailFolders', final name] when _wellKnown.contains(name) => graphFixture('folder_$name'),
  ['messages', _] || ['messages', _, 'attachments', _, r'$value'] => graphFixture('not_found'),
  _ => fail('unexpected ${r.method} $path'),
};

void main() {
  test('an HTML body asks for HTML, writes nothing and asks no attachments when it has none', () async {
    final g = RecordedGraph(_route);
    final body = okValue(await g.provider.fetchBody(messageIdOf('f1')));
    expect(body.kind, BodyKind.html);
    expect(body.content, contains('perché è già pronto'));
    expect(body.attachments, isEmpty);
    final r = g.requests.single;
    expect(r.method, 'GET', reason: 'opening a body never writes: the message stays unread');
    expect(r.headers['prefer'], contains('outlook.body-content-type="html"'));
    expect(r.headers['prefer'], contains('IdType="ImmutableId"'));
    expect(r.url.queryParameters[r'$select'], 'body,hasAttachments');
  });

  test('a plain text body is text', () async {
    final g = RecordedGraph(_route);
    final body = okValue(await g.provider.fetchBody(messageIdOf('f3')));
    expect((body.content, body.kind), ('Solo testo.', BodyKind.testo));
  });

  test('the logo the HTML shows by cid: is no attachment; the nameless, the empty, the attached message and the '
      'OneDrive link are', () async {
    final g = RecordedGraph(_route);
    final body = okValue(await g.provider.fetchBody(messageIdOf('f2')));
    expect(body.attachments!.map((a) => (a.id, a.name, a.size, a.mimeType)), [
      ('att-1', 'Preventivo.pdf', 19, 'application/pdf'),
      ('att-3', '', 4, 'application/pdf'),
      ('att-4', 'vuoto.txt', 0, 'text/plain'),
      ('att-5', 'Re: cena', 20, 'message/rfc822'),
      ('att-6', 'Foto vacanza', 0, 'text/plain'),
    ]);
    expect(g.requests.map((r) => r.method).toSet(), {'GET'});
  });

  test('an attachment downloads its bytes, an empty file none', () async {
    final g = RecordedGraph(_route);
    final progress = <double>[];
    final bytes = okValue(await g.provider.fetchAttachment(messageIdOf('f2'), 'att-1', onProgress: progress.add));
    expect(utf8.decode(bytes), 'ciao');
    expect(progress.last, 1);
    expect(okValue(await g.provider.fetchAttachment(messageIdOf('f2'), 'att-4')), isEmpty);
  });

  test('a message gone is NotFound, for its body and for its attachments', () async {
    final g = RecordedGraph(_route);
    expect(await g.provider.fetchBody(messageIdOf('f8')), isErr<NotFoundFailure>());
    expect(await g.provider.fetchAttachment(messageIdOf('f8'), 'att-1'), isErr<NotFoundFailure>());
  });

  test('a 401 on a body refreshes the token and asks again', () async {
    final tokens = <String?>[];
    final provider = MicrosoftProvider(
      graphAccount,
      graphKeychain(access: 'EwB.stale'),
      _Hanging((r) {
        if (r.url.host == tokenHost) return graphFixture('token_refresh');
        tokens.add(r.headers['authorization']);
        return tokens.length == 1 ? graphFixture('unauthorized') : graphFixture('body_f1');
      }),
      FakeClock(graphNow),
      client: graphTestClient,
    );
    expect(okValue(await provider.fetchBody(messageIdOf('f1'))).content, isNotEmpty);
    expect(tokens, ['Bearer EwB.stale', 'Bearer EwB.refreshed']);
  });

  test('Annulla aborts the download in flight', () async {
    final started = Completer<void>();
    final cancel = Completer<void>();
    final provider = MicrosoftProvider(
      graphAccount,
      graphKeychain(),
      _Hanging((r) => r.url.host == tokenHost ? graphFixture('token_refresh') : null, started: started),
      FakeClock(graphNow),
      client: graphTestClient,
    );
    final r = provider.fetchAttachment(messageIdOf('f2'), 'att-1', cancel: cancel.future);
    await started.future;
    cancel.complete();
    expect(await r, isErr<CancelledFailure>());
  });

  test('a Conversazione is asked of the whole mailbox: the old reply in Inviati comes with its Etichetta', () async {
    final g = RecordedGraph(_route);
    final messages = okValue(await g.provider.fetchConversation('conv-c1'));
    expect(messages.map((m) => (m.id, m.labelIds.single, m.date.year, m.date.month)), [
      ('msg-f1', inboxLabelId, 2026, 10),
      ('msg-f9', sentLabelId, 2026, 6),
    ]);
    final asked = g.requests.firstWhere((r) => r.url.path.endsWith('/messages'));
    expect(asked.url.queryParameters[r'$filter'], "conversationId eq 'conv-c1'");
    expect(asked.url.queryParameters[r'$select']!.split(','), isNot(contains('body')), reason: 'headers only');
    expect(asked.url.path, isNot(contains('mailFolders')), reason: 'no folder, no date window');
  });

  test('a quote in a Conversazione id is doubled in the filter', () async {
    final g = RecordedGraph(_route);
    okValue(await g.provider.fetchConversation("x' or isRead eq true or conversationId eq 'y"));
    final asked = g.requests.firstWhere((r) => r.url.path.endsWith('/messages'));
    expect(asked.url.queryParameters[r'$filter'], "conversationId eq 'x'' or isRead eq true or conversationId eq ''y'");
  });
}

/// Answers with [answer], or (null) hangs until the request is aborted, as a stalled download would.
class _Hanging(final http.Response? Function(http.Request r) answer, {final Completer<void>? started})
    extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = http.Request(request.method, request.url)..headers.addAll(request.headers);
    if (answer(r) case final response?) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.bodyBytes.length,
        headers: response.headers,
      );
    }
    started?.complete();
    await (request as http.Abortable).abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
}
