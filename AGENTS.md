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

Una PR si unisce solo se tutti i check *richiesti* (`check`, `android`, `apple`, GitGuardian) sono verdi sull'ultimo commit (nessuno fallito o in attesa). `check`, `android` e `apple` girano sul runner self-hosted `postino-mac`. I build hosted `linux` e `windows` girano solo a mano (`workflow_dispatch`) per risparmiare minuti Actions: vederli saltati è normale. La regola è imposta anche da un ruleset su `main`.

### Review prima del push

Prima di aprire una PR o di pushare su una PR esegui la skill `supermatt:code-review` rispetto a `origin/main` con il peer di `docs/agents/cross-model.json` e correggi i finding fondati: ogni finding di Codex su GitHub costa un giro push/review/CI. Dopo ogni push su PR pronta commenta `@codex review` (Codex resta il controllo finale).

### Accessibilità

Ogni ticket che crea o modifica componenti UI include nei criteri di accettazione le etichette semantiche per lo screen reader e la navigazione da tastiera secondo `docs/adr/0014-navigazione-da-tastiera.md`, verificate in QA con VoiceOver su macOS. Contrasto WCAG 2.2 AA e testo fino al 200% seguono le regole del design system (#53).
