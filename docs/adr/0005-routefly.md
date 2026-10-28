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

## Note di implementazione (routefly 3.1.3)

- Il path di un layout è la sua cartella: `posta/posta_layout.dart` → `/posta`. Una pagina con lo stesso path non può esserne figlia, quindi la Posta unificata la disegna il layout stesso quando nessuna rotta figlia è attiva (`Routefly.currentOriginalPath` uguale al path del layout); altrimenti mostra il `RouterOutlet`.
- Le pagine dei segmenti dinamici prendono il nome del segmento tra parentesi, accanto alla sua cartella: `posta/[accountId]_page.dart` → `/posta/[accountId]`, `posta/[accountId]/conversazione/[id]_page.dart` → `/posta/[accountId]/conversazione/[id]`, con `// ignore_for_file: file_names`. Il collasso del suffisso di routefly costruisce una regex dal segmento grezzo, per cui `[id]/[id]_page.dart` non collassa mai (pare un bug di routefly).
- I parametri si leggono con `Routefly.query['id']`.
- I path si costruiscono dall'accessor generato `routePaths`, mai a mano, es. `routePaths.posta.$accountId.path.changes({'accountId': id})`. Una cartella con rotte figlie diventa un record e il suo path è in `.path`: quando `posta` avrà figli, `routePaths.posta` in `main.dart` diventa `routePaths.posta.path`.
- routefly tiene la configurazione del router in campi statici: nei test una configurazione di rotte diversa va in un file di test a parte.
