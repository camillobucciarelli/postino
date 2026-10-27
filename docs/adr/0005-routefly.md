---
status: Accettato
date: 2026-10-27
---

# Navigazione con routefly

Le pagine (`*_page.dart`) stanno in `lib/app`, organizzate per URL (es. `posta/[accountId]/conversazione/[id]`), con una sola directory base di routefly (file-based routing). Su desktop i pannelli usano `*_layout.dart` + `RouterOutlet`. Aprire una Conversazione è una rotta, il che dà deep link dalle notifiche e tasto indietro su Android. Le pagine sono sottili e importano la presentazione delle feature. Nello stesso quadro: i18n con slang (it + en dalla v1) e stato con signals.

## Alternative considerate

- **`@Main('lib/features')` con cartelle `(group)`**: permetterebbe di tenere le pagine dentro le feature, ma è non documentato.

## Conseguenze

- Rischio aperto: il deep link da avvio a freddo dalla notifica non è documentato in routefly; va verificato con un prototipo prima di contarci.
