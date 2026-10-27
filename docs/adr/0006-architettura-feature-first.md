---
status: Accettato
date: 2026-10-27
---

# Clean architecture feature-first

Struttura: `lib/core/{domain,data}` (entità condivise Messaggio, Conversazione, Account, Etichetta; interfacce dei repository; use case condivisi come PosticipaMessaggio; adapter dei Provider, DB, Drive, sync, coda offline), `lib/features/<feature>/{domain,data,presentation}`, `lib/app` (pagine routefly), `lib/design_system`, `lib/i18n`.

Regole: le feature importano solo core e design_system, mai altre feature (ciò che si condivide sale in core); il domain è Dart puro (niente Flutter); le pagine non importano data. Gli use case esistono solo quando orchestrano più repository, altrimenti lo stato chiama direttamente i repository. Errori con `Result<T>` sealed (`Ok`, `Err(Failure)`) e `Failure` sealed. DI con injectable + get_it. Le regole sono verificate da un test Dart di circa 30 righe che scansiona gli import.

## Alternative considerate

- **Layer-first** (`lib/domain`, `lib/data`): le feature si disperdono tra i layer.
- **Package separati / monorepo**: isolamento forte ma overhead sproporzionato.
- **Use case per ogni azione**: boilerplate senza orchestrazione da giustificarlo.
- **`Either` di fpdart**: dipendenza in più rispetto ai sealed class del linguaggio.
- **DI manuale**: più codice di cablaggio da mantenere.

## Conseguenze

- La sezione 05 del design system (struttura `lib/features/<feature>/pages/`) è obsoleta e va aggiornata.
