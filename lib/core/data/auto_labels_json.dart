import 'dart:convert';

import '../domain/auto_label.dart';
import 'postino_database.dart';

/// The Etichette automatiche of an Account as the JSON voce of the Impostazioni di Postino (ADR 0004):
/// `{"<labelId>": {"automatic": true, "description": "…", "activatedAt": <ms epoch>}}`. Reading is lenient both ways: a file written
/// before the voce or a field existed, or a malformed one, reads as not automatica and no description;
/// unknown fields are ignored, for files written by a newer version. An Etichetta automatica without activation
/// (saved before it existed, or by an older Postino) takes [activatedFallback].
Map<String, AutoLabel> decodeAutoLabels(String? json, {int? activatedFallback}) {
  final Object? root;
  try {
    root = json == null ? null : jsonDecode(json);
  } on FormatException {
    return {};
  }
  if (root is! Map<String, dynamic>) return {};
  return {
    for (final MapEntry(:key, :value) in root.entries)
      if (value is Map<String, dynamic>)
        key: (
          automatic: value['automatic'] == true,
          description: switch (value['description']) {
            final String d when d.trim().isNotEmpty => d,
            _ => null,
          },
          activatedAt: switch (value['activatedAt']) {
            final int at => at,
            _ when value['automatic'] == true => activatedFallback,
            _ => null,
          },
        ),
  };
}

/// The key of the voce of [accountId] in the Impostazioni di Postino.
String autoLabelsKey(String accountId) => 'auto_labels/$accountId';

/// The Etichette automatiche in [row]: one without activation is active since the voce was written, a time that
/// stays put, as the next write of the voce saves it.
Map<String, AutoLabel> autoLabelsOf(PostinoSettingRow? row) =>
    decodeAutoLabels(row?.value, activatedFallback: row?.updatedAt);

/// Null when nothing is left to keep: no Etichetta automatica and no description.
String? encodeAutoLabels(Map<String, AutoLabel> labels) {
  final kept = {
    for (final MapEntry(:key, :value) in labels.entries)
      if (value.automatic || value.description != null)
        key: {'automatic': value.automatic, 'description': ?value.description, 'activatedAt': ?value.activatedAt},
  };
  return kept.isEmpty ? null : jsonEncode(kept);
}
