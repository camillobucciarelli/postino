// GmailLabels on recorded HTTP responses (#105): users.labels and the label changes of users.messages.modify.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/gmail_recorded.dart';

const _f1 = '18f3a2b4c5d6e7f1';

void main() {
  test('creating one posts the name, shown in lists, and returns the new Etichetta', () async {
    final g = RecordedGmail(
      (r, path) => switch ((r.method, path)) {
        ('GET', 'labels') => 'labels',
        ('POST', 'labels') => 'label_create',
        _ => fail('unexpected $path'),
      },
    );
    expect(
      okValue(await g.provider.createLabel('Fatture')),
      const Label(id: 'Label_31', name: 'Fatture', kind: LabelKind.etichetta),
    );
    expect(jsonDecode(g.requests.last.body), {
      'name': 'Fatture',
      'labelListVisibility': 'labelShow',
      'messageListVisibility': 'show',
    });
  });

  test('a name already taken, in any case, returns that Etichetta without posting', () async {
    final g = RecordedGmail((r, path) => r.method == 'GET' ? 'labels' : fail('unexpected ${r.method} $path'));
    expect(okValue(await g.provider.createLabel('viaggi')).id, 'Label_12');
  });

  test('adding and removing one modify the message', () async {
    final g = RecordedGmail((r, path) => path == 'messages/$_f1/modify' ? 'message_modify' : fail('unexpected $path'));
    okValue(await g.provider.setLabel(_f1, 'Label_12', add: true));
    okValue(await g.provider.setLabel(_f1, 'Label_12', add: false));
    expect(g.requests.map((r) => r.method), ['POST', 'POST']);
    expect(g.requests.map((r) => jsonDecode(r.body)), [
      {
        'addLabelIds': ['Label_12'],
      },
      {
        'removeLabelIds': ['Label_12'],
      },
    ]);
  });

  test('on a message gone it is NotFound', () async {
    final g = RecordedGmail((r, path) => 'not_found');
    expect(await g.provider.setLabel(_f1, 'Label_12', add: true), isErr<NotFoundFailure>());
  });

  test('a name taken by another client between the list and the post (409): returns that Etichetta', () async {
    var lists = 0;
    final g = RecordedGmail(
      (r, path) => switch ((r.method, path)) {
        ('GET', 'labels') => ++lists == 1 ? 'labels' : 'labels_fatture',
        ('POST', 'labels') => 'label_conflict',
        _ => fail('unexpected $path'),
      },
    );
    expect(
      okValue(await g.provider.createLabel('fatture')),
      const Label(id: 'Label_31', name: 'Fatture', kind: LabelKind.etichetta),
    );
    expect(lists, 2);
  });

  test('a refused post with the name still missing stays an Err', () async {
    final g = RecordedGmail((r, path) => r.method == 'GET' ? 'labels' : 'bad_request');
    expect(await g.provider.createLabel('Fatture'), isErr<RejectedFailure>());
  });
}
