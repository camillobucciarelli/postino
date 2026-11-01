# Spike litehtml via FFI: esiti dei tre prototipi

Rapporto per il ticket #66 (prototipo, figlio della spec #28). Contesto: i corpi HTML sono resi oggi con `flutter_widget_from_html` (ADR 0007) e le newsletter si rompevano (#63, #67; corrette in parte da #64 e #68); il pacchetto vero `packages/litehtml_flutter` è previsto in v3. Fonti: i tre branch locali `spike/66-litehtml-macos`, `spike/66-litehtml-memory`, `spike/66-litehtml-a11y` (commit del 2026-10-30), letti il 2026-11-01 senza checkout. I tre branch sono solo locali, non pushati: vanno pushati o taggati prima del merge di questo documento, altrimenti gli hash citati non saranno più raggiungibili. Gli output delle misure (PNG, `timings.txt`, `mem.txt`, dump AX) erano scritti fuori dal repo e non sono stati ritrovati: dove un numero manca è scritto **non misurato**.

Legenda: **[F]** fatto letto da commit, codice o test, **[I]** inferenza o stima, **[R]** raccomandazione.

## 1. Domanda

Legare litehtml v0.10 (BSD-3, gumbo incluso) a Flutter via FFI è fattibile e quanto costa? Il layout delle newsletter (tabelle, `bgcolor`, float, larghezze delle colonne, bordi, media query) è vicino al browser? Le callback sincrone C++→Dart per la misura del testo reggono, con quali tempi? Quanto costa arrivare a un pacchetto usabile sulle 5 piattaforme, con accessibilità e selezione? Requisito di prodotto da rispettare (#69): tutto il testo del corpo selezionabile e copiabile insieme al resto della Conversazione.

## 2. Contesto comune ai tre spike

I tre branch partono dagli stessi due commit (`08a62b3` vendorizzazione, `97bb1cb` prototipo) e divergono da lì: memoria e accessibilità non si conoscono a vicenda. **[F]**

**Architettura realizzata [F]**

- Conteggi riferiti al commit base `97bb1cb`; i branch successivi crescono (vedi sotto).
- `src/litehtml_c.h`: API C con 6 funzioni (`lh_create`, `lh_render`, `lh_height`, `lh_content_width`, `lh_draw`, `lh_destroy`) e una struct di 9 callback: misura (`create_font`, `text_width`, `get_image_size`) e disegno (`draw_text`, `fill_rect`, `draw_borders`, `draw_image`, `push_clip`, `pop_clip`). Tutte sincrone, sul thread che chiama `lh_render`/`lh_draw`. Il branch `memory` aggiunge `lh_debug_counts`, `a11y` aggiunge `lh_a11y_json` e `lh_text_json`.
- `src/litehtml_c.cpp` (207 righe; 218 su `memory`, 391 su `a11y`): `document_container` che inoltra alle callback. Stub vuoti per `load_image`, `import_css` (niente rete), `create_element`, `on_anchor_click`, `set_cursor`. Media: tipo `screen`, larghezza = viewport, altezza 800, 96 dpi, lingua `it`. Gradienti resi con il primo colore. `text-transform` solo ASCII.
- `lib/litehtml_flutter.dart` (371 righe; 453 su `memory`, 824 su `a11y`): callback con `NativeCallable.isolateLocal`, misura con `TextPainter` (cache delle larghezze per font e stringa), disegno su `Canvas`, `LitehtmlView(html, width)` con `CustomPaint` e altezza calcolata nel `build`. Stato globale (font, canvas corrente) condiviso tra documenti. `LitehtmlStats` conta le callback per nome.
- Font: risolti per nome dal sistema; generiche mappate su Helvetica, Times New Roman, Courier New; x-height stimata a 0,52 em; `delete_font` è un no-op (i font vivono in una cache Dart mai svuotata).
- Immagini: rettangoli grigi; dimensione letta dall'header IHDR per i data URI PNG, altrimenti 0×0 e litehtml usa `width`/`height` dell'HTML.

**Scelta di build [F]**: native assets (`hook/build.dart` + `native_toolchain_c` 0.19.5, `hooks` 2.2.0, `code_assets` 2.1.0). Gumbo compilato come libreria statica C (`c99`), litehtml più wrapper come dinamica C++17 che linka gumbo; `-w` per zittire i warning upstream. Perché **[I]**: nessun CMake né podspec, la stessa compilazione serve `flutter test`, `flutter run` e `flutter build`; `plugin_ffi` non è stato provato (non ce n'è traccia nei branch). Il pubspec richiede Flutter ≥ 3.38 e il progetto è fissato a 3.47.8 (`.fvmrc`).

**Vendorizzazione [F]**: `packages/litehtml_flutter/third_party/litehtml/` con `src/`, `include/`, `LICENSE`, `README.md` del tag v0.10 (commit `9bc84b8b`), senza CMake. Il file `VERSION` elenca le patch locali (marcate `PATCH postino`):

| Patch | File | Branch | In `VERSION` |
|---|---|---|---|
| `max-width` rispettato sulle tabelle (`width="100%"` + `max-width:600px`) | `src/render_table.cpp` | tutti | sì |
| `height` di `<td>` come altezza minima della riga (spaziatori) | `src/render_table.cpp` | tutti | sì |
| `<style>` non spezzato in parole | `src/document.cpp` | solo memory | no |
| Run di spazi in un solo `el_space` | `src/document_container.cpp` | solo memory | no |

**Come si riproduce [F]** (dopo checkout del branch):

- Da `packages/litehtml_flutter`: `fvm flutter test`; su `a11y` girano `a11y_test.dart` (2 test), `selection_test.dart` (3), `hostile_test.dart` (1) con le fixture in `test/fixtures/`; `render_demo_test.dart` si salta senza `--dart-define=LH_IN=/a.html,/b.html --dart-define=LH_OUT=/cartella` (HTML fuori dal repo: dati personali).
- Da `packages/litehtml_flutter/example` (qui stanno `macos/` e `lib/`): `fvm flutter build macos --release --dart-define=LH_IN=… --dart-define=LH_OUT=… --dart-define=LH_EXIT=true` compila soltanto; poi va avviato l'eseguibile prodotto in `build/macos/Build/Products/Release/` (oppure `fvm flutter run -d macos --release` con gli stessi `--dart-define`). Scrive PNG e `timings_release.txt` (11 giri per larghezza: il primo, di riscaldamento, è escluso dalla mediana, che è su 10).
- Memoria (branch `memory`, da `example`): `fvm flutter build macos --profile -t lib/mem_main.dart --dart-define=LH_IN=… --dart-define=LH_OUT=…`, poi avvio dell'eseguibile in `Products/Profile/` (oppure `fvm flutter run -d macos --profile -t lib/mem_main.dart …`); scrive `mem.txt`.
- Accessibilità (branch `a11y`, da `example`): app avviata con `LH_AX=1` nell'ambiente e `--dart-define=LH_SEMANTICS=true` (ad esempio `LH_AX=1 fvm flutter run -d macos --release --dart-define=LH_SEMANTICS=true`); `kill -USR1 <pid>` stampa l'albero NSAccessibility.

## 3. Spike 1: fattibilità su macOS (`spike/66-litehtml-macos`)

**Metodo [F]**: fixture sintetica `test/fixtures/features.html` con 15 casi numerati (bgcolor su `table`/`td`, media query su larghezza, `prefers-color-scheme`, `max-width` su tabella, colonne a larghezza fissa, float, bordi arrotondati e per lato, liste, flex, gradiente, immagine, `text-transform`, spaziatore `td height=40`); le due newsletter di prova indicate nella issue rese a 700 e 1000 px in PNG, da confrontare a occhio con il browser. Nessuna asserzione automatica sui PNG.

**Risultati [F]** (dal codice e dalle patch; il confronto visivo non è documentato nel branch):

| Area | Esito |
|---|---|
| Tabelle | Layout di litehtml. Servite due patch: `max-width` ignorato e `height` delle celle non rispettata (spaziatori). Colonne con `width` fisso e percentuale coperte dalla fixture. |
| `bgcolor` | Gestito da litehtml stesso (`el_table`, `el_tr`, `el_td` leggono l'attributo), senza toppe in Dart. |
| Float | Supportati da litehtml; caso 7 della fixture, nessuna asserzione. |
| Bordi | Per lato, colore e spessore; raggi solo se i quattro lati sono uguali; `dotted`/`dashed` disegnati pieni. |
| Font | Famiglia, peso, corsivo, sottolineatura; caduta sulle famiglie successive. Nei test i `.ttc` di sistema non si caricano: Helvetica è Arial. |
| Media query | Larghezza aggiornata a ogni `lh_render` (`media_changed`); altezza fissa 800. `prefers-color-scheme` non esiste in litehtml v0.10 (nessuna occorrenza nel sorgente): il caso 3 "non deve applicarsi" è vero per assenza. |
| Immagini | Rettangolo grigio `#D0D0D0` della dimensione dichiarata. |
| Altro | Flex supportato da litehtml; gradienti = primo colore; liste numerate disegnate da litehtml via `draw_text`; `text-transform` solo ASCII; `<link>`/`@import` ignorati (nessuna rete, coerente con ADR 0007). |

**Numeri**: la strumentazione c'è (tempo di layout, di registrazione della `Picture`, conteggio callback per tipo, RSS con 20 documenti vivi), i valori no.

| Misura | Valore |
|---|---|
| Tempo di layout per email (700 / 1000 px) | non misurato (nessun output nel repo) |
| Tempo di draw (registrazione `Picture`) | non misurato |
| Callback FFI per layout e per draw | non misurato |
| RSS per 20 documenti vivi | superato dallo spike 2 |

**Limiti [F]**: layout sincrono dentro `build` sull'isolate UI; stato globale (un solo `Canvas` corrente, cache font condivisa); nessun click sui link (nessun `GestureDetector`, `on_anchor_click` vuoto); cache delle larghezze mai svuotata; eccezioni nelle callback inghiottite da `exceptionalReturn`.

## 4. Spike 2: memoria (`spike/66-litehtml-memory`)

**Metodo [F]**: `example/lib/mem_main.dart`, build profile (serve il VM service). Tre misure per passo, 20 documenti alla volta, valori per documento: native = `malloc_zone_statistics` (tutte le zone), Dart = `getMemoryUsage` dopo GC forzato (`getAllocationProfile gc=true`), RSS = `ProcessInfo.currentRss` dopo `malloc_zone_pressure_relief`. Passi: documento minimo `<p>x</p>`; dopo `lh_create`; dopo layout (con e senza GC); con `Picture` registrata; solo `Picture` con DOM liberato; tutto liberato; 200 cicli crea/layout/disegna/distruggi (più `LH_CYCLES`) per i leak; LRU con 2 DOM vivi su 20. `lh_debug_counts` conta elementi, `el_space` e testi del DOM. Modalità `LH_HOLD` per `heap <pid>`.

**Numeri** (solo quelli nel messaggio di commit `ea3a7e0` e nei commenti; la tabella per passo di `mem.txt` non è nel repo):

| Scenario (una newsletter di prova, 700 px) | Prima | Dopo | Fonte |
|---|---|---|---|
| Documento con DOM litehtml vivo | ~7–11 MB | ~2 MB | commit [F] |
| Documento fuori vista (solo `Picture`, DOM liberato) | n/d | ~0,2 MB | commit [F] |
| Peso di un `el_text`/`el_space` | ~1,2 KB | invariato | commento in `document.cpp` [F] |
| Peso medio di un elemento DOM | ~1 KB | invariato | doc di `LitehtmlDocument` [F] |
| Valori per passo, leak dopo 200 cicli, quale delle due newsletter dà 7 e quale 11 MB | non misurato (non riportato) | | |

**Cosa è cambiato [F]**: due patch a litehtml (il CSS dentro `<style>` non viene più spezzato in `el_text` una parola alla volta; i run di spazi diventano un solo `el_space`, con i `\n` separati per `white-space: pre*`); in Dart `LitehtmlDocument` conserva l'HTML, registra una `Picture` per larghezza e tiene il DOM solo per gli ultimi `maxLiveDoms` documenti (LRU globale, default 2); `releaseDom` libera il nativo, un cambio di larghezza ricrea il DOM e rifà il layout; `_Painter` disegna la `Picture`.

**Limiti [F]**: LRU per numero di documenti, non per byte; la patch a `split_text` cambia la tokenizzazione del testo di tutto il motore e nel branch non c'è un test che la copra; le due patch non sono registrate in `VERSION`; le cache font/larghezze in Dart restano globali e non vengono mai liberate; con DOM liberato non ci sono hit-test, selezione né albero a11y finché non viene ricreato.

## 5. Spike 3: accessibilità e selezione (`spike/66-litehtml-a11y`)

**Metodo [F]**: dopo il layout il wrapper C++ (`a11y_walker`, +184 righe) esporta due JSON: l'albero di accessibilità (paragrafi, titoli con livello, link con `href`, immagini con `alt`, ognuno con rettangolo, in ordine di documento, testo con spazi collassati, `display:none`/`visibility` esclusi, `&nbsp;` soli scartati) e le parole con font e rettangolo, con `"\n"` ai confini di blocco. In Dart: `CustomPainterSemantics` con `OrdinalSortKey`, `header`/`headingLevel`, `link`/`linkUrl`, `image`, `onTap` sui link; un `RenderBox` `_SelectionLayer` con un `Selectable` registrato nella `SelectionArea` dell'app (hit-test per parola con `TextPainter`, offset per carattere, evidenziazione dipinta sul `Canvas`). Export JSON senza buffer fissi, coordinate finite e limitate a ±1e7, UTF-8 non valido → U+FFFD, NUL → U+FFFD prima della stringa C; `LitehtmlDocument.bytes` per corpi con UTF-8 malformato (accetta solo UTF-8, anche rotto: `lh_create` imposta sempre `encoding::utf_8`; il charset MIME, ad esempio ISO-8859-1, va decodificato prima dall'app, altrimenti il testo esce corrotto). L'esempio macOS avvolge la vista in una `SelectionArea`, misura il costo dell'albero e con `LH_AX=1` accende il bridge AX senza VoiceOver e stampa l'albero NSAccessibility su `SIGUSR1`.

**Risultati [F]** (test che passano per costruzione del commit; non rieseguiti qui):

| Requisito | Coperto | Prova |
|---|---|---|
| Trascinamento nel corpo + Cmd+C copia il testo con a capo ai blocchi | sì | `selection_test` 1 |
| Selezione che parte da un `Text` fuori dal corpo ed entra nell'HTML | sì | `selection_test` 2 |
| Cmd+A seleziona anche il corpo, insieme al resto dell'app | sì | `selection_test` 3 |
| Evidenziazione con il colore di selezione del tema | sì | `selection_test` 1 |
| Doppio click = parola | sì (codice) | nessun test |
| Ruoli, etichette, livelli dei titoli, ordine di documento anche con celle affiancate | sì | `a11y_test` fixture |
| `alt` vuoto = decorativa; immagine in un link dà il nome al link; link senza testo → dominio | sì | `a11y_test`, codice |
| Attivazione link da screen reader (`SemanticsAction.tap`) | sì | `a11y_test` |
| HTML ostile (UTF-8 rotto, controlli, misure enormi, NUL, `javascript:`) senza eccezioni né NaN | sì | `hostile_test` |
| `<br>` dentro un paragrafo: a capo nella copia | no: `<p>uno<br>due</p>` si copia come "unodue" (il walker aggiunge uno spazio solo al testo accessibile, non emette un separatore nel testo selezionabile) | codice (`litehtml_c.cpp`, ramo `br`); nessun test |
| Selezione per paragrafo, estensione da tastiera (Shift+frecce), granularità | no (`ponytail:` nel codice) | |
| Maniglie touch (`pushHandleLayers` vuoto) | no | |
| Selezione conservata dopo un relayout (cambio larghezza) | no: viene azzerata | |
| Copia come testo ricco (solo `plainText`) | no | |
| Click del mouse sui link, focus da tastiera (Tab) sui link | no | |
| Verifica con VoiceOver su macOS | non documentata: la strumentazione c'è, nessun dump nel repo | |
| Tempo di costruzione dell'albero a11y, numero di nodi per newsletter | non misurato | |

Il requisito «tutto il testo selezionabile e copiabile» è coperto per il testo visibile del corpo via mouse e scorciatoie, dentro la `SelectionArea` della Conversazione come chiede #69. Non è coperto per l'`alt` delle immagini (per scelta, come nel browser), per il `<br>` dentro un paragrafo (a capo perso nella copia), per la tastiera e per il touch.

**Limiti [F]**: albero a11y e testo ricalcolati a ogni `build` (export JSON completo, parsing in Dart); un `TextPainter` per parola creato pigramente per l'hit-test; ricerca lineare sulle parole; ordine dei nodi = ordine di documento, non visivo.

## 6. Rischi aperti

- **Branch non pushati**: i tre branch esistono solo in locale; vanno pushati o taggati prima del merge di questo documento, altrimenti gli hash citati diventano irraggiungibili.
- **Tre branch divergenti**: `lib/litehtml_flutter.dart`, `src/litehtml_c.cpp`, `src/litehtml_c.h` e `example/lib/main.dart` differiscono tra `memory` e `a11y` per lo stesso path; la LRU libera il DOM, ma selezione e Semantics lo richiedono dopo ogni `build`. Il merge va progettato (albero e testo esportati una volta e tenuti con la `Picture`).
- **Numeri non registrati**: tempi, callback, tabella per passo della memoria, costo dell'albero a11y. Senza, la stima di costo e il "GO" si fondano sul fatto che gli harness girano, non su soglie.
- **Layout sincrono nell'isolate UI** (`LitehtmlView.build` → `lh_render`): con una Conversazione lunga o una newsletter pesante blocca i frame. Spostarlo in un isolate richiede un contesto per documento al posto dei globali e font misurabili fuori dall'isolate principale.
- **Patch a litehtml** (4 patch in 3 file): da riapplicare a ogni aggiornamento upstream; `split_text` modificato senza test; `VERSION` incompleto.
- **Cache font/larghezze mai svuotate** (`_fonts`, `_fontIds`, `widths`): crescono con ogni stringa misurata; il test dei 200 cicli le misura ma l'esito non è riportato.
- **Font per piattaforma**: la risoluzione per nome vale su macOS; su Android, Windows e Linux le famiglie delle newsletter (Helvetica, Georgia) non esistono e la caduta su Arial/Times va definita; nei test i `.ttc` non si caricano.
- **Immagini vere, link, cursore**: tutto fuori scope dello spike; l'integrazione con «Mostra immagini» e Mittenti fidati (ADR 0007) è da fare.
- **Tema scuro**: `prefers-color-scheme` non esiste in litehtml; il cartoncino chiaro di ADR 0007 resta la regola.
- **Build su 5 piattaforme**: verificata solo su macOS con clang; `-w` e `std: c99/c++17` sono flag in stile clang/gcc, con MSVC vanno condizionati; nessun job CI tocca il pacchetto.

## 7. Raccomandazione per l'adozione

**[R] GO condizionato** per il pacchetto `packages/litehtml_flutter` in v3. Il nodo tecnico della issue (callback sincrone C++→Dart, layout di tabelle con `bgcolor`, spaziatori e `max-width`, disegno su `Canvas`, selezione nella `SelectionArea` dell'app, Semantics con ordine di documento) è dimostrato con codice e test. Il confronto visivo PNG/browser chiesto dalla issue non è documentato nei branch: il GO poggia su codice, patch e test, non su quel confronto, che va rifatto e registrato insieme ai numeri. Le condizioni: prima di scrivere il pacchetto, rieseguire i tre harness sulle due newsletter di prova e registrare i numeri in questo documento; se il layout a 700 px supera qualche decina di ms per email [I], il primo passo diventa il layout fuori dall'isolate UI.

**Cosa portare nel pacchetto vero [R]**: l'API C e il `document_container` dello spike 1 con le due patch alle tabelle; le due patch di memoria più un test su `split_text`; `LitehtmlDocument` con `Picture` e LRU; `a11y_walker` e il `Selectable`, con export fatto una volta per layout e conservato insieme alla `Picture`; `hostile_test`, `a11y_test`, `selection_test` e le fixture. Da riscrivere: lo stato globale (un contesto per documento), la risoluzione dei font per piattaforma.

**Ordine suggerito [R]**

1. Branch unico dai tre spike; contesto per documento; export a11y/testo cacheato; test verdi; numeri registrati.
2. Link (click, cursore, focus da tastiera) e immagini vere con le regole di ADR 0007.
3. Integrazione in `PostinoHtmlCard` dietro un interruttore, con fwfh come ripiego; QA con VoiceOver; criteri di accessibilità e tastiera per i componenti UI secondo `docs/adr/0014-navigazione-da-tastiera.md` (come chiede AGENTS.md).
4. Build e CI su iOS e Linux (stesso toolchain clang/gcc), poi Android (NDK, 4 ABI), poi Windows (MSVC).
5. Selezione da tastiera e touch, copia ricca.

**Costo per 5 piattaforme**

| Voce | Verificato | Stima [I] |
|---|---|---|
| Build macOS con native assets | sì (test e app) | — |
| Build iOS | no | 1–2 giorni: stesso clang, link statico preferibile per la firma |
| Build Linux | no | 1–2 giorni: clang/gcc già nel job CI |
| Build Android | no | 3–5 giorni: NDK via `native_toolchain_c`, 4 ABI, `libc++_shared` |
| Build Windows | no | 3–5 giorni: MSVC, flag condizionati, litehtml upstream compila con MSVC |
| CI per il pacchetto (test + 5 build) | no | 2–3 giorni; allunga i job esistenti |
| Fusione dei tre spike + contesto per documento + misure | no | 1–2 settimane |
| Link, immagini, integrazione nell'app, font per piattaforma | no | 2–3 settimane |
| Accessibilità completa (VoiceOver, TalkBack, Narrator, Orca) e selezione tastiera/touch | parziale (macOS, test automatici) | 2–3 settimane |
| Totale | | 7–11 settimane/persona (somma delle righe: giorni 10–17 ≈ 2–3,5 settimane a 5 giorni/settimana, più 5–8 settimane delle tre voci in settimane); l'incertezza maggiore è su Windows e Android e sulle prestazioni, non misurate |
