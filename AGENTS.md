## Agent skills

### Issue tracker

Issue e spec stanno su GitHub Issues (CLI `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Le sette label canoniche, con il nome di default. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` nella root e ADR in `docs/adr/`. See `docs/agents/domain.md`.

### External peers

Modalità `auto` (adapter Claude/Codex scelto dall'host, effort high). See `docs/agents/cross-model.json`.

### Merge delle PR

Una PR si unisce solo se tutti i check CI sono verdi sull'ultimo commit (nessuno fallito, in attesa o saltato). La regola è imposta anche da un ruleset su `main`.

### Accessibilità

Ogni ticket che crea o modifica componenti UI include nei criteri di accettazione le etichette semantiche per lo screen reader e la navigazione da tastiera secondo `docs/adr/0014-navigazione-da-tastiera.md`, verificate in QA con VoiceOver su macOS. Contrasto WCAG 2.2 AA e testo fino al 200% seguono le regole del design system (#53).
