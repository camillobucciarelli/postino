# Icona app e splash

Logo V3 «Grafico e piatto» (#194). L'unica fonte sono gli SVG in `assets/brand/` (viewBox 256, nessun filtro: l'ombra è una forma piatta):

| File | Uso |
| --- | --- |
| `icon.svg` | icona piena (tile verderame, busta aperta, lettera) |
| `icon-small.svg` | stessa icona con righe più spesse, usata sotto i 64 px |
| `icon-dark.svg` | iOS dark |
| `icon-tinted.svg` | iOS tinted (solo grigi, niente oro) |
| `mark.svg` | solo busta e lettera, senza tile: foreground Android |
| `mark-closed.svg` | busta chiusa, lettera nascosta: la posa a 0 ms dell'animazione (golden `brand_mark_closed`), usata dallo splash nativo |
| `mark-mono.svg` | silhouette Android monochrome (Material You) e template della tray macOS |
| `wordmark.svg` | «Postino» in Caprasimo (il serif dei titoli, `PostinoText.serif`), già convertito in tracciati |
| `lockup.svg` | generato: tile + «Postino» in inchiostro `#1c1c1a`, per fondi chiari |
| `lockup-dark.svg` | generato: marchio + «Postino» in carta `#fffdf8`, per fondi scuri o verderame |

Colori del marchio («carta e sabbia», solo token di `PostinoPrimitives`, gli stessi del painter): tasca (davanti
della busta) `pNeutral300` `#cdc8bb`, lettera `pNeutral0` `#ffffff`, falda e interno `pNeutral400` `#a6a093`, righe
della lettera `pNeutral300` `#cdc8bb`, riga d'accento `pGold400` `#f0c419`. La tasca resta più scura della lettera
così la lettera si stacca dalla busta. `icon-tinted.svg` ripete lo stesso salto in grigi (tasca `#cacaca`, lettera
`#fff`).

Lockup: il marchio è alto 152 unità, l'area di rispetto (76, metà del marchio) è già dentro il viewBox; scritta a 40
dal marchio, maiuscole alte 96 centrate sul marchio. Sui fondi chiari il marchio senza tile sparirebbe (carta su
carta), quindi `lockup.svg` usa il tile. `wordmark.svg` è stato estratto una volta da `assets/fonts/Caprasimo-Regular.ttf`
con fontTools e uharfbuzz (shaping con kerning), nessun `<text>`: rende uguale senza il font installato. Va rifatto
solo se cambia il font dei titoli.

## Rigenerare i PNG

```sh
tool/brand_icons.sh
```

Rasterizza con `rsvg-convert` se installato, altrimenti con `sips` (di serie su macOS). Riscrive i PNG committati:

- iOS: `AppIcon.png`, `AppIcon-dark.png`, `AppIcon-tinted.png` (1024, senza alfa, a tutto campo: la maschera la mette iOS) e `LaunchImage*.png` (da `mark-closed.svg`).
- macOS: `app_icon_16…1024.png`. Il tile occupa 824/1024 al centro (griglia Big Sur) con margine trasparente; `rx 57/256` coincide già con la squircle di macOS.
- Android: `ic_launcher.png` (legacy), `ic_launcher_foreground.png` e `ic_launcher_monochrome.png` (marchio al 30% della tela 108 dp, dentro la zona sicura di 66 dp), `drawable-*/splash_mark.png` (splash fino ad Android 11, da `mark-closed.svg`) e `drawable-*/splash_icon.png` (Android 12+: tela 288 dp con la busta chiusa di 128 dp al centro, dentro il cerchio di 192 dp della maschera di sistema, `windowSplashScreenAnimatedIcon` in `values-v31` e `values-night-v31`).
- Icona piccola delle notifiche Android (#285): non generata, `android/app/src/main/res/drawable/ic_stat_postino.xml` è un vector scritto a mano dalla silhouette di `mark-mono.svg` (22 dp su 24, solo alfa, righe della lettera da `icon-small.svg`). Se cambia il marchio, va aggiornata a mano.
- Tray desktop (#257): `assets/tray/tray_icon_template.png` (macOS, 36 px = 18 pt @2x, silhouette nera con alfa da `mark-mono.svg`, caricata come *template image*: la barra dei menu la colora per tema chiaro/scuro e stato evidenziato; `icon-small.svg` non serve, la silhouette è già leggibile) e `assets/tray/tray_icon.png` (Windows e Linux, 64 px a colori da `icon.svg`; nativeapi carica un solo bitmap e lo scala alla misura del tray, quindi niente `.ico` multi-risoluzione).
- Lockup: `assets/brand/lockup.svg` e `lockup-dark.svg`, composti da `icon.svg`/`mark.svg` e `wordmark.svg`.
- Open Graph (#268): `docs/download/og.png`, 1200×630 senza alfa, gradiente del tile con `lockup-dark.svg` centrato.
  Le pagine prodotto lo nominano in `og:image` (URL assoluto, `twitter:card` `summary_large_image`), `release.yml`
  (job `site`) lo pubblica alla radice del bucket e `download_check.sh` controlla meta e file.

macOS 26 (Icon Composer, `.icon` a livelli) non c'è ancora: con un `AppIcon.icon` nel target, Xcode genera anche le
icone per macOS < 26 dal `.icon` e ignora `app_icon_*.png`, perdendo la posa `icon-small.svg` sotto i 64 px. Prova e
decisione da prendere nel commento di follow-up di #268.

Il fondo adattivo Android (`drawable/ic_launcher_background.xml`) e il verderame dello splash (`values/colors.xml`, `LaunchScreen.storyboard`) sono scritti a mano: se cambiano i colori in `assets/brand/`, aggiornarli.

Il sito (`docs/download/`) usa questi stessi file: `release.yml` (job `site`) pubblica `icon.svg` (logo) e `icon-small.svg` (favicon) in `brand/` sul bucket, senza copie.

Splash nativo: statico, la busta chiusa (`mark-closed.svg`) su verderame, identica al fotogramma a 0 ms dell'animazione, così il passaggio all'animazione non ha salti. Se cambia la posa a 0 ms del painter, aggiornare `mark-closed.svg` (il golden `brand_mark_closed` lo mostra). macOS non ha launch screen.

All'avvio, dopo lo splash nativo, `PostinoBrandIntro` (#267, nel `builder` di `MaterialApp.router`) copre l'app col verderame dello splash e il marchio che si apre una volta (`PostinoBrandMark`, 900 ms: lembo 250 ms, lettera 650 ms), poi dissolve. L'app si costruisce sotto dal primo frame e riceve input; con «riduci movimento» non c'è copertura. Il painter ricopia le geometrie di `mark.svg`: se cambia, aggiornarlo.
