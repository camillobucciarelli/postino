# Icona app e splash

Logo V3 «Grafico e piatto» (#194). L'unica fonte sono gli SVG in `assets/brand/` (viewBox 256, nessun filtro: l'ombra è una forma piatta):

| File | Uso |
| --- | --- |
| `icon.svg` | icona piena (tile verderame, busta aperta, lettera) |
| `icon-small.svg` | stessa icona con righe più spesse, usata sotto i 64 px |
| `icon-dark.svg` | iOS dark |
| `icon-tinted.svg` | iOS tinted (solo grigi, niente oro) |
| `mark.svg` | solo busta e lettera, senza tile: splash e foreground Android |
| `mark-mono.svg` | silhouette Android monochrome (Material You) |

## Rigenerare i PNG

```sh
tool/brand_icons.sh
```

Rasterizza con `rsvg-convert` se installato, altrimenti con `sips` (di serie su macOS). Riscrive i PNG committati:

- iOS: `AppIcon.png`, `AppIcon-dark.png`, `AppIcon-tinted.png` (1024, senza alfa, a tutto campo: la maschera la mette iOS) e `LaunchImage*.png`.
- macOS: `app_icon_16…1024.png`. Il tile occupa 824/1024 al centro (griglia Big Sur) con margine trasparente; `rx 57/256` coincide già con la squircle di macOS.
- Android: `ic_launcher.png` (legacy), `ic_launcher_foreground.png` e `ic_launcher_monochrome.png` (marchio al 30% della tela 108 dp, dentro la zona sicura di 66 dp), `drawable-*/splash_mark.png`.

Il fondo adattivo Android (`drawable/ic_launcher_background.xml`) e il verderame dello splash (`values/colors.xml`, `LaunchScreen.storyboard`) sono scritti a mano: se cambiano i colori in `assets/brand/`, aggiornarli.

Il sito (`docs/download/`) usa questi stessi file: `release.yml` (job `site`) pubblica `icon.svg` (logo) e `icon-small.svg` (favicon) in `brand/` sul bucket, senza copie.

Splash: statico (marchio su verderame), senza animazione. macOS non ha launch screen.
