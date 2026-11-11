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
    expect(r.url.queryParameters[r'$select'], 'body,uniqueBody,hasAttachments');
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

  test('logo-1 is not taken for logo-10: only the image the HTML shows is left out', () async {
    http.Response route(http.Request r, String path) => switch (path.split('/')) {
      ['messages', _] => graphJson({
        'hasAttachments': true,
        'body': {'contentType': 'html', 'content': '<img src="cid:logo-10">'},
      }),
      ['messages', _, 'attachments'] => graphJson({
        'value': [
          {'id': 'att-1', 'name': 'a.png', 'size': 1, 'isInline': true, 'contentId': 'logo-1'},
          {'id': 'att-2', 'name': 'b.png', 'size': 1, 'isInline': true, 'contentId': 'logo-10'},
        ],
      }),
      _ => fail('unexpected $path'),
    };
    final body = okValue(await RecordedGraph(route).provider.fetchBody(messageIdOf('f2')));
    expect(body.attachments!.map((a) => a.id), ['att-1']);
  });

  test('a Graph that refuses contentId on the attachment list gets the list without it', () async {
    final g = RecordedGraph((r, path) {
      if (path.endsWith('/attachments') && r.url.queryParameters[r'$select']!.contains('contentId')) {
        return graphJson({
          'error': {'code': 'RequestBroker-ParseUri', 'message': 'no contentId'},
        }, 400);
      }
      return _route(r, path);
    });
    final body = okValue(await g.provider.fetchBody(messageIdOf('f2')));
    expect(
      body.attachments!.map((a) => a.id),
      ['att-1', 'att-3', 'att-4', 'att-5', 'att-6'].where((id) => id != 'att-2'),
    );
  });

  test('progress follows the chunks of the download', () async {
    final progress = <double>[];
    final provider = MicrosoftProvider(
      graphAccount,
      graphKeychain(),
      _Chunked(),
      FakeClock(graphNow),
      client: graphTestClient,
    );
    okValue(await provider.fetchAttachment(messageIdOf('f2'), 'att-1', onProgress: progress.add));
    expect(progress, [0.25, 0.5, 0.75, 1, 1], reason: 'the last 1 is the end of the download');
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

/// Answers with a download of four chunks of one byte.
class _Chunked() extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == tokenHost) {
      final r = graphFixture('token_refresh');
      return http.StreamedResponse(Stream.value(r.bodyBytes), 200, headers: r.headers);
    }
    return http.StreamedResponse(
      Stream.fromIterable([
        for (var i = 0; i < 4; i++) [i],
      ]),
      200,
      contentLength: 4,
    );
  }
}
