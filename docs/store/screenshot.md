# Screenshot

**Stato: non prodotti.** Postino non ha una modalità demo né dati di prova: l'unico modo di mostrare una Posta in arrivo è collegare un Account vero, e il compito vieta di usare posta o account del titolare o l'app già installata con i suoi dati. Un server IMAP/SMTP locale con posta finta e le build iOS e macOS (iOS richiede ancora #323) sono un lavoro a sé, che non ho forzato: restano da fare con l'account demo di [checklist-titolare.md](checklist-titolare.md) (posta di esempio non personale) sul simulatore iOS e su una build macOS fresca, mai sull'istanza già installata.

Le immagini, quando ci sono, vanno in `docs/store/screenshot/<piattaforma>/<lingua>/NN-nome.png`, senza trasparenza, sRGB, PNG o JPEG, senza cornici di dispositivo (Apple le rifiuta se non sono lo schermo reale).

## Risoluzioni accettate da App Store Connect

Basta **una** dimensione per famiglia: Apple ridimensiona le altre. Da 1 a 10 screenshot per localizzazione; se ne propongono 5.

| Famiglia | Dimensione (px, verticale × orizzontale) | Simulatore o dispositivo |
|---|---|---|
| iPhone 6.9" (obbligatoria) | 1320 × 2868 (anche 1290 × 2796, 1260 × 2736) | iPhone 17 Pro Max (simulatore disponibile) |
| iPad 13" (obbligatoria per iPad) | 2064 × 2752 (anche 2048 × 2732) | iPad Pro 13-inch (M5) |
| Mac | 1280 × 800, 1440 × 900, 2560 × 1600 o 2880 × 1800 | finestra di Postino della build macOS, ridimensionata a 1440 × 900 punti (@2x = 2880 × 1800) |

Le dimensioni vanno riverificate su App Store Connect al momento del caricamento: Apple le aggiorna con i nuovi dispositivi.

## Elenco delle schermate (per ogni famiglia e lingua)

Dati d'esempio: Account `demo@…` fittizio (nessun indirizzo reale), mittenti e oggetti inventati, nessun nome del titolare. Lingua dell'app: italiano per `it`, inglese per `en` (impostare la lingua del simulatore).

1. **Posta unificata** con almeno due Account di colore diverso, messaggi non letti e con Stella.
2. **Conversazione** aperta con corpo, allegato e il banner «Immagini remote bloccate».
3. **Ricerca** con un operatore (`da:`) e i risultati.
4. **Etichette automatiche**: pagina di un Account con una Etichetta attivata e il modello pronto.
5. **Azioni per scorrimento** (Impostazioni) oppure **Nuovo messaggio** nell'editor.

Su iPad e Mac la schermata 1 mostra le tre colonne (barra laterale, lista, conversazione).

Nome dei file: `01-posta-unificata.png`, `02-conversazione.png`, `03-ricerca.png`, `04-etichette-automatiche.png`, `05-scorrimento.png`.

## Come produrli (quando c'è l'account demo)

1. iPhone/iPad: `fvm flutter run -d <udid-del-simulatore>` con l'account demo, `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4`, poi `xcrun simctl io <udid> screenshot file.png`.
2. Mac: build macOS, finestra a 1440 × 900 punti, `screencapture -o -l <id finestra> file.png` (senza ombra).
3. Controllare a occhio che non compaiano posta, nomi o indirizzi reali.
