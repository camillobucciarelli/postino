# Struttura del codice

Regole decise dall'owner il 2026-11-04. Prevalgono su "meno file possibile": la brevità vale dentro il file, non nel numero di file.

## Un file, una responsabilità

- Un file contiene una classe pubblica (o un gruppo coeso di funzioni pure) con una sola ragione di cambiamento.
- Si spezza quando supera indicativamente ~300 righe o copre più di un ruolo: trasporto + parsing + mapping errori, widget + I/O, repository + coda.
- Un widget privato di supporto che supera ~80 righe va in un file proprio.

## SOLID

- **SRP**: come sopra.
- **OCP**: le scelte per Provider stanno in una factory, non in `switch` sparsi.
- **DIP**: dipendere dalle interfacce di `core/domain`, mai dai concreti di `core/data` (es. `MailSync`, non `SyncEngine`).
- Non rimuovere le interfacce di `core/domain` con una sola implementazione: servono ai fake di test.

## Clean architecture (ADR 0006)

- `core/domain` e `features/*/domain` non importano drift, http, enough_mail né Flutter.
- `features/*/presentation` e `app/` non importano `core/data`.
- Un use case in `domain` solo quando orchestra due o più repository; altrimenti lo stato chiama il repository.
- I widget non fanno I/O diretto: delegano a use case o repository.

## Drift

- Un file per tabella (`core/data/tables/`) e uno per DAO (`core/data/daos/`).

## Design system

- Il barrel `lib/design_system/design_system.dart` è stabile: gli split interni non cambiano gli import dei consumer.
- `Actions`/`Shortcuts` stanno nell'organismo radice (ADR 0014).

## Coda offline

- Un solo scheduler per Account (ADR 0008), anche dopo uno split di `SyncEngine`.

## Test

- `test/architecture_test.dart` fa rispettare le regole di import; ogni nuova regola di layer si aggiunge lì.
- I test seguono la stessa divisione dei file che coprono: un file sorgente spezzato, test spezzati allo stesso modo.

## Dart

- Effective Dart per naming e ordine dei membri; `dart format`; lint da `analysis_options.yaml`.
