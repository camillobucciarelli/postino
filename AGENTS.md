## Agent skills

### Issue tracker

Issue e spec stanno su GitHub Issues (CLI `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Le sette label canoniche, con il nome di default. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` nella root e ADR in `docs/adr/`. See `docs/agents/domain.md`.

### External peers

Modalità `auto` (adapter Claude/Codex scelto dall'host, effort high). See `docs/agents/cross-model.json`.

### Struttura del codice

Un file, una responsabilità; SOLID; clean architecture (ADR 0006) con le regole di import verificate da `test/architecture_test.dart`. Le regole prevalgono su "meno file possibile". See `docs/agents/struttura-codice.md`.

### Merge delle PR

Una PR si unisce solo se tutti i check *richiesti* (`check`, `android`, `apple`, GitGuardian) sono verdi sull'ultimo commit (nessuno fallito o in attesa). I job di `ci.yml` girano su runner hosted (repo pubblico: minuti gratis), con Flutter da `.fvmrc` via `subosito/flutter-action`: `static`, `test` (3 parti parallele di `flutter test`) e `apple` su `macos-26`, `android` su `ubuntu-latest`; `check` è verde solo se `changes`, `static` e tutte le parti di `test` sono verdi. `android` e `apple` (le build native) girano solo se la PR tocca `android/`, `ios/`, `macos/`, `packages/`, `pubspec.yaml`, `pubspec.lock`, `.fvmrc`, `ci.yml` o i due script di `tool/release` che usano; su `main` girano sempre, e un job saltato vale come verde per il ruleset. GitHub esegue al massimo 5 job macOS hosted insieme, quindi un sesto job macOS aspetta in coda; anche le PR da fork, perché il runner hosted non ha segreti né chiavi. Gli altri workflow (`release.yml`, `ios-version-file.yml`, `mutation.yml`, `play-key-export.yml`) girano sull'unico runner self-hosted `postino-mac` (macOS), che non esegue mai codice di una PR. Sulle PR `ci.yml` parte a ogni push e una run nuova cancella quella superata. I golden di `test/design_system` sono di riferimento per l'immagine `macos-26` del job `test`: un altro Mac disegna fino allo 0,3% dei pixel in modo diverso. Per rigenerarli c'è `update-goldens.yml` (`workflow_dispatch`, `commit` acceso sul branch della PR). Il cancello di Codex (#246) è stato rimosso: la review di Codex resta un controllo, ma non blocca più la CI. La regola è imposta anche da un ruleset su `main`.

### Review prima del push

Prima di aprire una PR o di pushare su una PR esegui la skill `supermatt:code-review` rispetto a `origin/main` con il peer di `docs/agents/cross-model.json` e correggi i finding fondati: ogni finding di Codex su GitHub costa un giro push/review/CI. Dopo ogni push su PR pronta commenta `@codex review` (Codex resta il controllo finale).

### Mutation test

Workflow `mutation.yml` ogni notte (al più 600 mutanti) e a mano sull'intera `lib/`, mai sulle PR; in locale `fvm dart run tool/mutation/run.dart --base=origin/main`. See `docs/agents/mutation-test.md`.

### Accessibilità

Ogni ticket che crea o modifica componenti UI include nei criteri di accettazione le etichette semantiche per lo screen reader e la navigazione da tastiera secondo `docs/adr/0014-navigazione-da-tastiera.md`, verificate in QA con VoiceOver su macOS. Contrasto WCAG 2.2 AA e testo fino al 200% seguono le regole del design system (#53).

### Design system

La fonte di verità è il codice in `lib/design_system/`; l'artefatto Claude Design https://claude.ai/artifact/NHTah8veqH7f9q2BbEcBKs lo rispecchia, non lo guida. Ogni PR che cambia token o componenti del design system aggiorna anche l'artefatto, oppure scrive nel corpo della PR «Artefatto da aggiornare» con l'elenco dei valori. Un valore non va mai duplicato con un secondo nome: riusa il token esistente (#264).
