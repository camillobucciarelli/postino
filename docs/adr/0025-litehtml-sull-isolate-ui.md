---
status: Accettato
date: 2026-11-24
---

# litehtml sull'isolate UI, limiti tarati sullo stack

litehtml (`packages/litehtml_flutter`, #383) chiede le misure del testo in modo sincrono mentre analizza e impagina (`create_font`, `text_width`), e il pacchetto le prende da `ui.Paragraph`, lo stesso motore del testo dell'app. Le callback sono `NativeCallable.isolateLocal`: si possono chiamare solo sul thread dell'isolate che le ha create. L'HTML delle email non è fidato e litehtml è ricorsivo sull'albero del DOM e dei token CSS: senza limiti, un'email annidata a qualche centinaio di livelli esaurisce lo stack del thread e fa cadere l'app.

## Decisione

Creazione, layout e disegno di un `LitehtmlDocument` girano sincroni sull'isolate UI, sul thread su cui Flutter lo esegue; il pacchetto non crea thread né isolate.

Siccome lo stack di quel thread non lo sceglie il pacchetto, i limiti di annidamento (patch `PATCH postino` in `third_party/litehtml/VERSION`) sono tarati perché il caso peggiore ammesso stia in uno stack piccolo:

- al più 512 elementi aperti nel parser HTML (oltre: `LitehtmlFailure.tooDeep`), DOM di litehtml profondo al più 128 (oltre: `tooDeep`), al più 32 blocchi e funzioni CSS annidati (oltre: blocco vuoto);
- misurato su arm64 (macOS, 2026-11-24): il caso peggiore usa meno di 160 KB di stack con `-O3`, l'ottimizzazione fissata in `hook/build.dart`, e meno di 384 KB con `-O0`;
- misurato su x86_64 (Linux, clang `-O3`, runner `ubuntu-latest`, 2026-11-24): il caso peggiore, 126 `display:flex` annidati, supera 256 KB e sta in 384 KB; gli altri casi stanno in 256 KB;
- `test/native/stack_test.sh` fa girare i casi peggiori in un thread con 256 KB di stack nel job `check` (macOS arm64) e con 384 KB nel job `linux` (x86_64). Su Windows (MSVC) non gira: lo script è clang e pthread, e lì i test Dart del pacchetto caricano la libreria senza misurarne lo stack.

Il margine è pensato sul thread più piccolo che può ospitare l'isolate UI. Da Flutter 3.29 su iOS e Android l'isolate UI gira sul thread principale della piattaforma (1 MB su iOS, 8 MB su Android); i thread secondari hanno di default 512 KB su iOS e Apple, circa 1 MB su Android e Windows. Questi valori sono di documentazione e non sono stati misurati sui dispositivi.

Il tempo è limitato da tre budget: HTML al più 4 MiB (`tooLarge`), 500 000 chiamate di layout per `layout()` (`layout`: le tabelle e i flex annidati costano in modo esponenziale), 500 000 celle di tabella per documento (`failed`). Le newsletter di prova impaginano in ~2 100 chiamate e ~13 ms dall'HTML alla `Picture` (`docs/research/litehtml-misure.md`).

## Alternative considerate

- **Isolate secondario**: `ui.Paragraph` lì lancia «UI actions are only available on root isolate», provato con `Isolate.run` in `flutter test`. Il layout andrebbe avanti con misure a zero. Servirebbe una misura nativa del testo per piattaforma (CoreText, DirectWrite, FreeType), diversa da quella dell'app. Inoltre una `Picture` non passa da un isolate all'altro, quindi i comandi di disegno andrebbero serializzati.
- **Thread nativo con stack grande**: la callback di misura deve restituire un valore, mentre `NativeCallable.listener` è asincrono. Un thread nativo che chiama in modo sincrono l'isolate UI, mentre il thread UI lo aspetta bloccato, va in stallo.
- **Shaper nativo (HarfBuzz)**: misure indipendenti da Flutter, ma una dipendenza grande e a capo diversi dal resto dell'app.

## Conseguenze

- Un'email blocca il frame per il tempo di creazione e layout: ~10–15 ms a caldo per una newsletter tipica, ~70 ms per il primo documento del processo. Per un HTML ostile da 4 MiB senza annidamento sono ~1–1,5 s, misurati con callback finte: resta un limite noto.
- Il layout delle tabelle annidate senza larghezze costa circa 3 volte per livello: da 11 livelli (18 con `width="100%"`) esaurisce il budget e l'email va al ripiego. Le newsletter di prova ne hanno meno; una cache delle misure delle celle in `render_table` è il rimedio se emergono email reali così.
- Ogni patch a litehtml che aggiunge ricorsione va rimisurata con `stack_test.sh`. Lo stesso vale per un cambio di ottimizzazione in `hook/build.dart`.
- Un HTML rifiutato (`LitehtmlException`) non è un crash: chi integra il motore (#383, fetta 2) ripiega su un altro motore.
