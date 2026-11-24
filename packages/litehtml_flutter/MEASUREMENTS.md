# Misure del prototipo litehtml (#66)

Registrate il 2026-11-23 con l'harness `example/` (build release, macOS 27.2.1, Apple M5 Pro, 24 GB, Flutter 3.50.0, Impeller/Metal). Numeri reali, copiati da `measurements-release.md` scritto dall'harness.

## Email di prova

Le newsletter citate dalla issue (Zalando, ProntoPro) non hanno riferimenti nel repo né nei rapporti: al loro posto due newsletter HTML pubbliche e complesse, tenute fuori dal repo in `~/Downloads/litehtml-spike-66/html/`:

| Nome | Sorgente | Peso | Caratteristiche |
|---|---|---|---|
| `colorlib-1` | `ColorlibHQ/email-templates`, cartella `1/index.html` (MIT, generata con MJML) | 93 KB | 116 `<table>`, 26 `bgcolor`, colonne 2/3/4, hero con `height`, `@media`, web font via `<link>` |
| `cerberus-hybrid` | `TedGoas/Cerberus`, `cerberus-hybrid.html` (MIT) | 40 KB | colonne ibride `inline-block`, tabelle `width=100%` + `max-width`, celle spaziatrici `height=40`, `dir=rtl`, `<center>`, `@media` |

## Come si riproduce

Da `packages/litehtml_flutter/example`:

```sh
fvm flutter build macos --release \
  --dart-define=LH_IN=$HOME/Downloads/litehtml-spike-66/html/colorlib-1.html,$HOME/Downloads/litehtml-spike-66/html/cerberus-hybrid.html \
  --dart-define=LH_OUT=$HOME/Downloads/litehtml-spike-66 --dart-define=LH_EXIT=true
./build/macos/Build/Products/Release/litehtml_example.app/Contents/MacOS/litehtml_example
```

Per ogni email e larghezza: 11 giri, ognuno con un documento nuovo (font e cache delle larghezze ripartono da zero). Il primo giro del processo è "freddo" (font di sistema caricati la prima volta); mediana e massimo sono sui 10 successivi.

- **Creazione** = `lh_create`: parse gumbo, CSS, stili calcolati. In litehtml v0.10 qui avviene anche la misura del testo: `el_text` misura ogni parola mentre calcola gli stili.
- **Layout** = `lh_render` alla larghezza data.
- **Draw** = `lh_draw` con i comandi dipinti da Dart su un `Canvas` registrato in una `Picture` (non include il raster della GPU).

## Tempi (versione finale, 4 patch)

| Email | Larghezza | Altezza (px) | Creazione freddo / mediana (ms) | Layout freddo / mediana / max (ms) | Draw freddo / mediana / max (ms) | Totale freddo / mediana (ms) | di cui `text_width` in Dart freddo / mediana (ms) | Stringhe misurate con `Paragraph` |
|---|---|---|---|---|---|---|---|---|
| colorlib-1 | 700 | 3831 | 62.4 / 8.3 | 1.4 / 1.3 / 1.3 | 5.9 / 4.3 / 5.6 | 69.7 / 14.2 | 2.9 / 1.7 | 166 |
| colorlib-1 | 1000 | 3831 | 10.0 / 8.0 | 1.3 / 1.2 / 1.3 | 4.1 / 4.0 / 5.6 | 15.4 / 13.3 | 3.0 / 1.6 | 166 |
| cerberus-hybrid | 700 | 1688 | 6.6 / 4.1 | 0.9 / 0.9 / 0.9 | 4.1 / 3.7 / 5.2 | 11.6 / 8.8 | 1.6 / 1.2 | 150 |
| cerberus-hybrid | 1000 | 1688 | 5.9 / 4.3 | 0.9 / 0.9 / 0.9 | 3.8 / 3.7 / 3.8 | 10.5 / 9.0 | 1.3 / 1.3 | 150 |

Altezze in Chrome alle stesse condizioni: colorlib-1 3844 px, cerberus-hybrid 1706 px (differenza 0,3 % e 1 %).

## Callback FFI (C++→Dart) per giro

Identiche a ogni giro e uguali a 700 e 1000 px. Il layout non chiama mai Dart: tutte le misure avvengono nella creazione.

| Email | Fase | Callback |
|---|---|---|
| colorlib-1 | creazione | `create_font` 17, `text_width` 2986 (tot. 3003) |
| colorlib-1 | layout | nessuna |
| colorlib-1 | draw | `draw_text` 474, `fill_rect` 55, `draw_borders` 9 (tot. 538) |
| cerberus-hybrid | creazione | `create_font` 11, `text_width` 1550 (tot. 1561) |
| cerberus-hybrid | layout | nessuna |
| cerberus-hybrid | draw | `draw_text` 460, `fill_rect` 29, `draw_borders` 3, `set_clip` 3, `del_clip` 3, `draw_image` 1 (tot. 499) |

## Effetto della patch sugli spazi (stessa macchina, stesse email)

Prima della patch `document.cpp` (un `el_space` per carattere di indentazione), con le altre tre patch già applicate:

| Email | Larghezza | `text_width` per giro | Creazione mediana (ms) | Totale mediana (ms) |
|---|---|---|---|---|
| colorlib-1 | 700 | 11985 | 15.8 | 22.4 |
| colorlib-1 | 1000 | 11985 | 14.6 | 20.7 |
| cerberus-hybrid | 700 | 8922 | 8.1 | 13.3 |
| cerberus-hybrid | 1000 | 8922 | 8.5 | 13.6 |

Dopo: `text_width` −75 % / −83 %, creazione circa dimezzata, layout e altezze identici.

## Lettura

- Una newsletter pesante costa ~13–14 ms dall'HTML alla `Picture` a caldo, ~70 ms la prima volta nel processo (caricamento dei font di sistema). Sull'isolate UI a 60 Hz il caso a caldo sta in un frame; il primo no.
- Un cambio di larghezza sullo stesso documento (`LitehtmlView` lo fa) costa solo layout + draw: ~5–6 ms, senza callback di misura [inferenza dai tempi di fase: vale se nessuna media query cambia stato; se cambia, `media_changed` ricalcola gli stili e rimisura].
- Le callback sincrone reggono: ~3000 attraversamenti per email, di cui il tempo dentro Dart è 1,2–1,7 ms a caldo; la cache per font riduce a ~150 le misure vere con `Paragraph`.
