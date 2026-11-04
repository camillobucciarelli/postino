# Spike #103 — embedding on-device per l'Etichettatura automatica

Codice usa e getta, non entra in `lib/`. Confronta runtime e modelli di embedding sulla classificazione delle email
nelle Etichette dell'utente: zero-shot (email contro nome + descrizione dell'Etichetta) e kNN sugli esempi etichettati.

## Struttura

- `data/emails.json` — dataset sintetico: 8 Etichette (`name`, `description`) e 80 email (10 per Etichetta, 40 IT e
  40 EN) con `id`, `label`, `lang`, `from`, `subject`, `body`. Lunghezze miste (16 email oltre 450 parole, per far
  contare il troncamento 256 vs 512 token) e qualche caso ambiguo (ordine con fattura, trasferta di lavoro, promo
  di una compagnia aerea, avvisi di sicurezza della banca). Le latenze si misurano sulle stesse email.
- `eval/` — package Dart puro (senza Flutter) che calcola le metriche dai JSON prodotti dai prototipi.

## Testo da embeddare

I prototipi devono embeddare esattamente questi testi (`eval/lib/embedding_text.dart`):

- email: `"Oggetto: <subject>\nDa: <from>\n\n<body>"`, troncato a 256 o 512 token dal prototipo con il tokenizer del
  modello;
- Etichetta: `"<name>: <description>"`.

Eventuali prefissi di task richiesti dal modello (es. `query: ` per multilingual-e5) li aggiunge il prototipo e li
indica nel campo `model`.

## Formato di scambio

Ogni prototipo scrive un file JSON per combinazione runtime/modello/troncamento:

```json
{
  "runtime": "llamadart",
  "model": "embeddinggemma-q8_0",
  "maxTokens": 512,
  "labels": [{ "name": "Viaggi", "embedding": [0.01, -0.2] }],
  "emails": [{ "id": "via-it-01", "label": "Viaggi", "lang": "it", "embedding": [0.03, 0.11] }]
}
```

## Valutatore

```sh
cd spikes/embedding/eval
dart pub get
dart run bin/eval.dart ../results/llamadart-gemma-512.json [altri.json ...]
dart test
```

Stampa una riga di tabella markdown per file e scrive `<file>.eval.json` accanto a ogni input. Metriche:

- zero-shot: Etichetta con coseno massimo;
- kNN leave-one-out (k = 3 e 5, voto pesato per coseno) e centroide leave-one-out: l'email non vede sé stessa;
- tutte le accuratezze anche separate per IT ed EN;
- zero-shot con astensione: copertura e precisione quando la top-1 supera la seconda di almeno 0, 0.02, 0.05.
