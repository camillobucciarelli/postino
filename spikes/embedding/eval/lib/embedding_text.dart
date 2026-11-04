/// Testi da passare al modello di embedding. I prototipi Flutter li riproducono
/// identici (vedi README), così tutti i candidati embeddano lo stesso testo.
///
/// Nessun prefisso di task: se un modello lo richiede (es. `query: ` / `passage: `
/// per multilingual-e5, `task: classification | query: ` per EmbeddingGemma) lo
/// aggiunge il prototipo e lo dichiara nel campo `model` del JSON di scambio.
library;

/// Testo di un'email: `Oggetto: <subject>\nDa: <from>\n\n<body>`.
///
/// Il troncamento a 256/512 token lo fa il prototipo con il tokenizer del modello.
String emailText({required String subject, required String from, required String body}) =>
    'Oggetto: $subject\nDa: $from\n\n$body';

/// Testo di un'Etichetta per lo zero-shot: `<name>: <description>`.
String labelText({required String name, required String description}) => '$name: $description';
