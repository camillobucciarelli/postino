---
status: Accettato
date: 2026-10-27
---

# Rendering delle email: widget Flutter su tutte le piattaforme, WebView solo per "Vedi originale"

I corpi HTML dei messaggi sono resi con `flutter_widget_from_html` (0.17.x) su tutte e 5 le piattaforme: un solo percorso di codice e nessun JavaScript per costruzione. Su iOS, Android e macOS l'azione "Vedi originale" apre il corpo in `webview_flutter` con JavaScript disabilitato, CSP con `img-src` limitato e link intercettati tramite `onNavigationRequest`.

## Regole di privacy e sicurezza

- Le immagini remote sono bloccate di default. Un Banner propone "Mostra immagini" (solo per questo messaggio) oppure "Sempre da questo mittente" (elenco dei mittenti fidati, salvato nelle Impostazioni di Postino).
- I link si aprono sempre nel browser di sistema. Se il testo visibile del link mostra un dominio diverso da quello reale di destinazione, un Dialog mostra prima il dominio reale.

## Tema scuro

I corpi HTML stanno su un "cartoncino" chiaro con angoli arrotondati dentro la UI scura; i corpi in testo semplice seguono il tema.

## Alternative considerate

- **WebView ovunque** (`webview_flutter` su mobile/macOS + `webview_win_floating` su Windows/Linux): la vista nativa è sovrapposta alla finestra Flutter, non si può ritagliare né coprire con Dialog o BottomSheet, e si comporta male dentro uno scroll.
- **`flutter_inappwebview`**: non supporta Linux e la release stabile è ferma dal 2024-10.
- **`webview_cef`**: binari CEF pesanti e progetto ancora giovane.
- **Abbandonare Linux**: rinuncia a una piattaforma per risolvere un problema di rendering.
- **Proxy per le immagini remote**: scartato perché non c'è un backend (ADR 0001).
- **Inversione automatica dei colori**: scartata perché rovina loghi e colori di brand.

## Conseguenze

- Le newsletter complesse (media query, layout CSS avanzato) perdono fedeltà.
- Su Windows e Linux, per ora, "Vedi originale" non esiste.
