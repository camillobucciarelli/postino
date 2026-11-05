import 'dart:convert';

import '../domain/auto_label.dart';

/// The Etichette automatiche of an Account as the JSON voce of the Impostazioni di Postino (ADR 0004):
/// `{"<labelId>": {"automatic": true, "description": "…"}}`. Reading is lenient both ways: a file written
/// before the voce or a field existed, or a malformed one, reads as not automatica and no description;
/// unknown fields are ignored, for files written by a newer version.
Map<String, AutoLabel> decodeAutoLabels(String? json) {
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
        ),
  };
}

/// Null when nothing is left to keep: no Etichetta automatica and no description.
String? encodeAutoLabels(Map<String, AutoLabel> labels) {
  final kept = {
    for (final MapEntry(:key, :value) in labels.entries)
      if (value.automatic || value.description != null)
        key: {'automatic': value.automatic, 'description': ?value.description},
  };
  return kept.isEmpty ? null : jsonEncode(kept);
}
