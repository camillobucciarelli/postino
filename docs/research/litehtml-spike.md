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
| Cmd+A seleziona anche il corpo, insieme al resto del contenuto della `SelectionArea` esterna (nell'app: la Conversazione, non l'intera finestra) | sì | `selection_test` 3 |
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

## 8. Ricostruzione (2026-11-23)

Il codice dei tre branch spike del 2026-10-30 è andato perso (mai pushato). Lo spike 1 è stato ricostruito da zero sul branch `spike/66-litehtml-macos`, questa volta pushato su `origin`, seguendo questo rapporto. Memoria (spike 2) e accessibilità/selezione (spike 3) non sono stati ricostruiti. Le misure sono in `docs/research/litehtml-misure.md` (era `packages/litehtml_flutter/MEASUREMENTS.md` sul branch dello spike); i PNG stanno fuori dal repo in `~/Downloads/litehtml-spike-66/`.

**Email di prova [F]**: le newsletter Zalando e ProntoPro della issue non hanno riferimenti nel repo né nei rapporti (HTML personali, mai salvati). Al loro posto due newsletter pubbliche (MIT) e complesse: `colorlib-1` (ColorlibHQ/email-templates n. 1, generata con MJML: 116 tabelle, 26 `bgcolor`, colonne, hero con `height`) e `cerberus-hybrid` (TedGoas/Cerberus: colonne ibride, `max-width` su tabelle `width=100%`, spaziatori `height=40`, `dir=rtl`, `<center>`). Nessun HTML di email nel repo.

**Scelta di build [F]**: native assets, come nel rapporto: `hook/build.dart` con `native_toolchain_c` 0.19.6 (`hooks` 2.2, `code_assets` 2.2). Gumbo come libreria statica C99, litehtml + wrapper come dinamica C++17 che la linka, `-w`. Ha funzionato al primo tentativo con Flutter 3.50.0 (`.fvmrc`, non più 3.47.8): `flutter test`, `flutter build macos --release` e l'app partono senza CMake né podspec. `plugin_ffi` non provato: non serviva. Prima compilazione ~45 s, poi in cache.

**Architettura [F]**: `src/litehtml_c.h` con 4 funzioni (`lh_create(html, width, cb)`, `lh_render`, `lh_draw`, `lh_destroy`) e 8 callback sincrone: misura (`create_font`, `text_width`) e disegno (`draw_text`, `fill_rect`, `draw_borders`, `draw_image`, `set_clip`, `del_clip`). Differenze dal rapporto: niente stato globale, perché ogni `LitehtmlDocument` crea le proprie `NativeCallable.isolateLocal`, i propri font e la propria cache delle larghezze, che muoiono con lui; niente `get_image_size` verso Dart; `lh_height` e `lh_content_width` tolte (`lh_render` restituisce l'altezza). `LitehtmlView(html, width)`: `StatefulWidget` che crea il documento, fa layout e registra una `Picture` all'`initState` o al cambio di html; un cambio di sola larghezza rifà layout e draw sullo stesso DOM; `CustomPaint` alto quanto il contenuto. Il layout resta sincrono sull'isolate UI.

**Immagini [F]**: rettangoli grigi `#D0D0D0`. La "dimensione dichiarata" è letta dagli attributi `width`/`height` di ogni `<img>` (visita del DOM dopo `lh_create`) e passata a litehtml come dimensione intrinseca: così `style="width:100%; height:auto"` dà il rapporto d'aspetto giusto, come fa il browser prima di caricare l'immagine. Con un solo attributo (es. `height=""`) l'immagine ha altezza 0, perché senza scaricarla non c'è modo di saperla. Gli sfondi CSS con immagine non si disegnano (resta il `background-color`).

**Confronto con il browser [F]**: Chrome 158 di sistema in headless (via `playwright-core` 1.49.1, script fuori dal repo), stessa larghezza, 2x, rete bloccata (niente web font, niente immagini), `<img>` sostituiti da PNG grigi della dimensione degli attributi e altezza 0 senza attributi: le stesse regole del prototipo, così il confronto misura il layout e non il caricamento. Affiancati in `<email>-<larghezza>-confronto.png` (litehtml a sinistra).

| Area | Esito sulle due email |
|---|---|
| Tabelle | Struttura, larghezze delle colonne e annidamenti come Chrome dopo 3 patch: `max-width` (sezione con testo bianco di Cerberus, larga come la pagina invece di 500 px), `height` dei `td` (spaziatori di 40 px ridotti a una riga di ~1 px; hero di Colorlib più basso: Chrome somma il padding all'`height` della cella), `cellpadding` (ogni cella teneva 1 px di padding: deriva verticale cumulativa). Altezza finale: 3831 contro 3844 px, 1688 contro 1706 px. |
| `bgcolor` | Corretto su `table`/`td` senza toppe (lo legge litehtml). |
| Colonne ibride / float | Colonne `inline-block` di Cerberus a 2 e 3 affiancate come in Chrome. Float: nessun caso nelle due email (MJML e Cerberus non li usano), coperto solo dal test sintetico dello spike perso. |
| Bordi | Bordi pieni e raggi uguali (bottoni arrotondati) uguali a Chrome; `dotted`/`dashed`/`double` disegnati pieni. |
| Font | Famiglie risolte da macOS (Georgia per Playfair, Helvetica per Montserrat/sans-serif): stessi a capo di Chrome quasi ovunque. `letter-spacing` **non supportato** da litehtml v0.10 (nessuna occorrenza nel sorgente): le etichette maiuscole di Colorlib sono più strette e "HAPPY CUSTOMERS" sta su una riga invece di due. |
| Media query | Valutate a ogni larghezza (test sul relayout 600→400 px); le due email non ne attivano nessuna a 700/1000. |
| `<center>` / `align=center` | Chrome usa `-webkit-center` (centra anche le tabelle-bottone figlie, ma le tabelle non lo ereditano); litehtml un `text-align:center` ereditato ovunque: prima della correzione il testo di Cerberus era centrato invece che a sinistra e il bottone dell'hero di Colorlib stava a sinistra. Corretto con due regole di user CSS nel wrapper (non una patch): copre i figli diretti, non il comportamento completo. |
| `dir=rtl` | Non supportato: la riga "testo a sinistra, immagine a destra" di Cerberus resta nell'ordine del sorgente. |
| Altro | Una riga chiara di 1 px tra alcune sezioni di Colorlib (arrotondamenti) che Chrome non ha; spaziature verticali delle colonne di Cerberus 10–15 px più strette di Chrome. |

**Patch a litehtml [F]** (marcate `PATCH postino`, elencate in `third_party/litehtml/VERSION`), ognuna applicata solo dopo averne visto l'effetto sui PNG o sulle misure:

| Patch | File | Nel rapporto precedente | Motivo |
|---|---|---|---|
| `max-width` sulle tabelle | `render_table.cpp` | sì | layout sbagliato visibile in Cerberus |
| `height` in px di `td` (più padding e bordi, come Chrome) come altezza minima della riga | `render_table.cpp` | sì (senza padding) | spaziatori e hero |
| `cellpadding` della tabella sul padding delle celle | `el_td.cpp` | **no, nuova** | litehtml v0.10 ignora l'attributo; deriva verticale su tutte le newsletter |
| Un `el_space` per run di spazi tra i tag (`\n` separati) | `document.cpp` | sì (spike memoria) | callback `text_width` −75/−83 %, creazione dimezzata |
| `<style>` non spezzato in parole | `document.cpp` | sì (spike memoria) | **non applicata**: il testo di `<style>` non genera callback di misura (verificato) e la memoria è fuori scope |

**Misure [F]** (release, Apple M5 Pro; dettaglio in `litehtml-misure.md`): dall'HTML alla `Picture` ~13–14 ms per Colorlib e ~9 ms per Cerberus a caldo, ~70 ms al primo documento del processo (font di sistema). Il layout vero e proprio è 0,9–1,6 ms e non chiama Dart; il draw 3,7–4,3 ms. Callback per email: ~1550–3000 `text_width` e 11–17 `create_font` alla creazione, ~500 di disegno; il tempo speso dentro le callback Dart di misura è 1,2–1,7 ms. Le soglie del §7 («qualche decina di ms a 700 px») sono rispettate a caldo; il primo documento le supera.

**Cosa non è stato verificato**: `LitehtmlView` dentro l'app demo è stata solo avviata (nessun errore, nessuno screenshot della finestra); i PNG vengono dalla stessa `Picture` che il widget dipinge. Nessuna misura di memoria; nessuna prova di selezione o Semantics; nessuna newsletter reale con dati (Zalando, ProntoPro), quindi immagini con soli attributi parziali, font web e casi `dir`/`letter-spacing` delle email vere restano da vedere.

**Differenze rispetto al rapporto precedente**: Flutter 3.50.0; API C più piccola e nessuno stato globale (uno dei "da riscrivere" del §7); dimensione delle immagini dagli attributi invece che dall'header PNG dei data URI; una patch nuova (`cellpadding`); una delle patch di memoria applicata per le prestazioni, l'altra no; numeri e confronto con il browser finalmente registrati; `letter-spacing`, `dir=rtl` e `-webkit-center` emersi come limiti non citati prima. La raccomandazione del §7 (GO condizionato) è confermata sulle condizioni di tempi e confronto visivo; restano aperte quelle su memoria e accessibilità, i cui spike non sono stati ricostruiti.

## 9. HTML non fidato (#383, fetta 1, 2026-11-24)

**Metodo [F]**: harness C++ fuori dal repo che crea, impagina, disegna e distrugge un documento con callback finte (larghezza del testo = 8 px per byte) in un thread con stack scelto, compilato come `hook/build.dart` (`-O3`) e anche `-O0`. Apple M5 Pro, arm64. La parte che conta è diventata `packages/litehtml_flutter/test/native/stack_test.sh` (stack di 256 KB, nel job `check`); i casi a 100 000 livelli sono anche test Dart (`test/litehtml_security_test.dart`).

**Prima delle patch [F]**, codice di `spike/66-litehtml-macos`, thread da 512 KB:

| Input | Esito |
|---|---|
| 1 000 `<div>` annidati; 800 `<div>`; 1 000 `@media{` | crash (stack overflow) |
| CSS `(` o `f(` annidati a 100 000 | crash (`consume_component_value` ↔ `consume_simple_block`) |
| 20 `<table><tr><td>` annidate senza larghezze | non finisce (layout esponenziale: 10 livelli = 30 ms) |
| 20 000 `<div>` annidati, stack da 8 MB | 1,7 s nel parser (ogni errore di Gumbo copia lo stack degli elementi aperti) |
| `<td colspan=0>`, `colspan=-5`, `rowspan=-3` | crash (indice di colonna/riga negativo) |
| 200 000 righe `<tr><td>` | 18 s (`is_rowspanned` quadratico) |
| 100 000 `<td colspan=1000>` | 20 s, ~10⁸ celle allocate |

**Patch [F]** (elenco in `third_party/litehtml/VERSION`): tetto di 32 blocchi CSS annidati; tetto di 512 elementi aperti in Gumbo (oltre: `html_too_deep` → `LitehtmlFailure.tooDeep`, non un documento troncato, così l'integrazione può ripiegare); DOM di litehtml al più 128 livelli (oltre: `tooDeep`; la prima versione appiattiva come Chrome, ma così `<style>` e `display:none` diventavano testo visibile); `destroy_node` di Gumbo iterativo; errori di Gumbo disattivati (`max_errors = 0`); budget di 500 000 `render_item::render` per layout; `colspan`/`rowspan` come nello standard HTML e budget di 500 000 celle per documento; `is_rowspanned` O(1). Nel wrapper: HTML oltre 4 MiB rifiutato, eccezioni di litehtml catturate, documento inutilizzabile dopo un layout fallito.

**Dopo le patch [F]**:

| Caso | Esito | Stack minimo `-O3` / `-O0` |
|---|---|---|
| 126 `<div>` (al tetto del DOM) | reso | 96 / 256 KB |
| 126 `<div style="float:left">` o `display:flex` | reso / budget di layout | 160 / 384 KB |
| 63 `<ul><li>` | reso | 96 / 256 KB |
| 127–511 elementi annidati | `tooDeep` | — |
| 31 `<table><tr><td>` | budget di layout (`-1`) in ~50 ms | 64 / 128 KB |
| 10 / 11 `<table><tr><td>` senza larghezze | reso in 30 ms / budget di layout | — |
| CSS annidato a 100 000 (`(`, `f(`, `{`, `@media{`, `:not(`) | reso, blocco profondo vuoto | 32 KB |
| 100 000 elementi annidati di qualsiasi tag | `tooDeep` in ~1 ms | 32 KB |
| newsletter di prova (colorlib-1, colorlib-10, cerberus, mailchimp) | altezze identiche a prima delle patch, 371–2 136 chiamate di layout | 32 KB |
| 349 000 `<div>` piatti (~4 MB) | reso in ~1,3 s | — |
| 200 000 righe / 400 000 celle in una tabella (~4 MB) | budget di layout dopo ~1,3–1,6 s | — |
| 100 000 `<td colspan=1000>` | `failed` (budget di celle) in 0,3 s | — |

**Isolate [F]**: in `flutter test`, `ui.ParagraphBuilder` dentro `Isolate.run` lancia «UI actions are only available on root isolate». Un `LitehtmlDocument` creato lì non va in crash, ma impagina con misure a zero perché le callback falliscono. Il layout resta quindi sull'isolate UI: la scelta e i margini di stack sono in ADR 0025.

**Build [F]**: app con il pacchetto come dipendenza: `flutter build macos --debug`, `flutter build ios --no-codesign` e `flutter build apk --debug --flavor site` riusciti; un test di integrazione temporaneo (documento normale, CSS annidato a 100 000, HTML annidato a 100 000 e a 200 livelli, 126 float annidati, tabelle annidate, HTML oltre il limite) è passato sul simulatore iOS (iPhone 17 Pro, iOS 27) e sull'emulatore Android arm64 (API 36). Sull'emulatore la prima prova falliva al caricamento: `dlopen failed: cannot locate symbol "atan2f"`, e la libreria chiedeva `libc++_shared.so`, che l'APK non contiene. Ora si linkano `libm` e `c++_static`. Windows e Linux non sono mai stati compilati: il solo runner è macOS e da macOS non si compila per quelle piattaforme.

**Cosa non è verificato**: lo stack reale del thread UI su ogni piattaforma (i valori in ADR 0025 vengono dalla documentazione); i frame di stack con MSVC e con gcc; i tempi con le callback Dart vere sui casi ostili da 4 MiB (le misure sopra usano callback finte).
