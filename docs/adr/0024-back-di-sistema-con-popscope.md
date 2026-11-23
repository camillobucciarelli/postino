---
status: Accettato
date: 2026-11-23
---

# Back di sistema con PopScope sul layout Posta

Su Android 16 con targetSdk 36 (Flutter 3.50) il predictive back è attivo di default: Android consegna il back a Flutter solo se l'app ha dichiarato di gestirlo (`SystemNavigator.setFrameworkHandlesBack`), cioè se il Navigator può fare pop o la sua ultima route ha un `PopScope` con `canPop: false`. Routefly non impila (`Routefly.navigate` sostituisce l'unica pagina), quindi senza `PopScope` Android chiudeva l'app anche con una Conversazione aperta o da un'altra lista, e il `BackButtonListener` di #237 non scattava mai (#365).

## Decisione

`PostinoListDetailLayout` (usato dal layout Posta e dalla Ricerca) avvolge tutto in un `PopScope`: `canPop` è falso finché c'è un dettaglio aperto o il chiamante passa `onListBack` (il layout Posta lo passa da ogni lista diversa dalla Posta unificata, per tornarci). Il back chiude nell'ordine: dialog e bottom sheet (route sopra, li gestisce il Navigator), drawer modale (il `PopScope` nasconde al Navigator le `LocalHistoryEntry`, quindi il layout lo chiude con `navigator.pop()`), selezione di testo (lo stesso `PostinoClearSelectionIntent` di Esc), dettaglio (`onClose`, come Esc), poi `onListBack`; sulla Posta unificata senza nulla aperto decide il sistema (predictive back e app in background). Sotto i 900 px su iOS, che non ha un back di sistema, uno swipe dal bordo sinistro del dettaglio a tutto schermo oltre un terzo della finestra (o un colpo veloce) chiama `onClose` con l'animazione esistente; l'area è fuori dall'albero semantico, quindi non tocca VoiceOver.

## Alternative considerate

- **Dettaglio come pagina vera sotto i 900 px**: darebbe il pop e l'anteprima predictive animata gratis, ma richiede di riscrivere `PostaLayout` e il passaggio stretto↔largo, che oggi tiene lo stato di lista e dettaglio con le GlobalKey dello stesso albero.

## Conseguenze

- Niente anteprima predictive animata dentro l'app, né swipe iOS che segue il dito (fuori ambito in #365).
- I test (`test/support/system_back.dart`) simulano il back come lo consegna Android 16: arriva all'app solo se l'ultima dichiarazione sul canale `flutter/platform` è `true`.
