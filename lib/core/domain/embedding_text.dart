import 'html_text.dart';
import 'message.dart';

/// The characters of the body given to the model.
// ponytail: a cut in characters, so the text stays small; the cut to the model's 256 tokens is the adapter's.
const maxEmbeddedBody = 1000;

/// The text of an email for the embedding model, in the format of the spike #103:
/// `Oggetto: <subject>\nDa: <from>\n\n<body>`, the body as plain text, or the snippet when it is not downloaded.
String emailEmbeddingText(Message m, MessageBody? body) {
  final text = switch (body) {
    null => m.snippet,
    MessageBody(kind: BodyKind.html, :final content) => htmlText(content),
    MessageBody(:final content) => content,
  };
  final cut = text.length > maxEmbeddedBody ? text.substring(0, maxEmbeddedBody) : text;
  return 'Oggetto: ${m.subject}\nDa: ${m.from}\n\n$cut';
}

/// The text of an Etichetta for the zero-shot start: `<name>: <description>`, the name alone without one.
String labelEmbeddingText(String name, String? description) => description == null ? name : '$name: $description';
