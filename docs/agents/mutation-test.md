# Mutation test (#235)

Il mutation test cambia il codice di `lib/` e controlla che i test se ne accorgano: un mutante sopravvissuto è una riga che i test eseguono senza verificarla.

- Strumento: [`mutation_test`](https://github.com/domohuhn/mutation-test) (dev dependency), guidato da `tool/mutation/run.dart`.
- Mutazioni: solo quelle di `tool/mutation/rules.xml` (`&&`/`||`, confronti, `+ - *`, `true`/`false`, `!` tolto, `if` negato, `return;` anticipato tolto), mai dentro commenti, stringhe senza interpolazione, import e intestazioni dei cicli. Un mutante che non compila conta come ucciso.
- File: Dart scritto a mano sotto `lib/`; i generati (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `*.route.dart`) mai.
- Test: per `lib/a/b.dart` solo `test/a/b_test.dart`, se esiste, altrimenti i test che importano `package:postino/a/b.dart`. Prima delle mutazioni quei test girano una volta con la coverage: se sono rossi il file non si misura, e i mutanti su righe non eseguite si contano come "non coperti" senza lanciarli.
- Punteggio: (uccisi + timeout) / tutti, non coperti compresi.
- I sorgenti si ripristinano dopo ogni mutante, e anche con Ctrl-C o SIGTERM.

## In locale

```sh
# File modificati rispetto a origin/main, come sulla PR
fvm dart run tool/mutation/run.dart --base=origin/main
# Percorsi scelti (separati da virgola)
fvm dart run tool/mutation/run.dart --path=lib/core/domain/search_query_parser.dart,lib/core/data/
```

Opzioni: `--max-mutants=N` (campione deterministico: un candidato ogni `ceil(n / N)` per file e riga, dichiarato nel report; 0 = tutti), `--threshold=P` (exit 1 sotto P%), `--timeout=S` (secondi per esecuzione dei test, 120), `--out=DIR` (`build/mutation`), `--flutter=CMD` (`flutter`, cioè quello nel `PATH`, come sul runner). Report in `build/mutation/report.md`.

Costo: circa 4 secondi a mutante su un M-series più un'esecuzione dei test per file.

## In CI

Workflow `.github/workflows/mutation.yml`, job `mutation` sul runner `postino-mac`. **Non** è un check richiesto.

- Sulle PR: solo i file modificati, al più 120 mutanti, `timeout-minutes: 30`. Senza file mutabili finisce subito con successo.
- A mano (Actions › Mutation › Run workflow): `path` (default `lib/`) e `max-mutants` (default 0, tutti).
- Report nel summary del job e nell'artifact `mutation-report`.
- Soglia: `MUTATION_THRESHOLD` in testa al workflow, oggi `0` (il job fallisce solo per errori dello strumento).
