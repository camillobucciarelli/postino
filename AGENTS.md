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

Una PR si unisce solo se tutti i check *richiesti* (`check`, `android`, `apple`, GitGuardian) sono verdi sull'ultimo commit (nessuno fallito o in attesa). `check`, `android` e `apple` girano sul runner self-hosted `postino-mac`. Sulle PR `ci.yml` parte a ogni push ma il passo «Codex gate» (`tool/ci/gate.sh`) fa fallire i tre job in pochi secondi, prima di Flutter, finché il commit di testa non è approvato (#246): fallire e non saltare, perché un check richiesto saltato conta come verde. Approva la testa la ricevuta di Codex «Didn't find any major issues» con `**Reviewed commit:**` uguale alla testa; a mano, se Codex non risponde (limite d'uso, nessuna ricevuta), un commento `ci-ok <sha della testa>` di un collaboratore con permesso di scrittura (letto dall'API, non dal testo). All'approvazione `.github/workflows/codex-ok.yml` rilancia la run `pull_request` di quel commit (`tool/ci/rerun.sh`); se non parte, `gh run rerun <id>` a mano. Una PR da fork che non modifica `ci.yml` fallisce al primo passo invece di saltare i check; contro una che lo modifica protegge solo l'impostazione del repo sui workflow delle PR da fork. Flusso: push → `@codex review` → ok di Codex → CI rilanciata → merge a check verdi. Ogni push successivo va riapprovato. La regola è imposta anche da un ruleset su `main`.

### Review prima del push

Prima di aprire una PR o di pushare su una PR esegui la skill `supermatt:code-review` rispetto a `origin/main` con il peer di `docs/agents/cross-model.json` e correggi i finding fondati: ogni finding di Codex su GitHub costa un giro push/review/CI. Dopo ogni push su PR pronta commenta `@codex review` (Codex resta il controllo finale): senza il suo ok sul commit di testa la CI della PR si ferma al cancello.

### Mutation test

Job `mutation` sulle PR (solo i file Dart modificati, non richiesto) e workflow manuale sull'intera `lib/`; in locale `fvm dart run tool/mutation/run.dart --base=origin/main`. See `docs/agents/mutation-test.md`.

### Accessibilità

Ogni ticket che crea o modifica componenti UI include nei criteri di accettazione le etichette semantiche per lo screen reader e la navigazione da tastiera secondo `docs/adr/0014-navigazione-da-tastiera.md`, verificate in QA con VoiceOver su macOS. Contrasto WCAG 2.2 AA e testo fino al 200% seguono le regole del design system (#53).
