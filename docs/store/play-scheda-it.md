# Scheda Google Play · italiano

Testi da incollare nella Play Console, **Crescita → Presenza sullo store → Scheda dello store principale**, lingua predefinita **Italiano – it-IT**. Tra parentesi il limite di Google in caratteri ([limiti](https://support.google.com/googleplay/android-developer/answer/9859152); conteggio nella tabella di [README.md](README.md)). Parte dalla scheda Apple ([scheda-it.md](scheda-it.md)) e descrive solo ciò che fa la variante Android «store»: niente iPhone, iPad e Mac, niente avviso di aggiornamento dal sito.

## Nome dell'app (30)

Lo stesso nome dell'App Store.

```
Postino Mail
```

## Descrizione breve (80)

Senza emoji, maiuscole di richiamo né inviti tipo «scarica ora» (regola di Google, stessa pagina).

```
Gmail, Outlook, iCloud e IMAP in una sola Posta in arrivo, cifrata e offline.
```

## Descrizione completa (4000)

```
Postino riunisce tutte le tue caselle email in un'unica Posta in arrivo, veloce anche senza rete.

UN SOLO POSTO PER TUTTA LA POSTA
Collega Gmail, Outlook.com e Microsoft 365 (Account personali e di lavoro o scuola), iCloud e qualsiasi casella IMAP. La Posta unificata li mette insieme, ordinati per data, e ogni Account ha il suo colore: capisci a colpo d'occhio da dove arriva un messaggio. Puoi sempre aprire un solo Account dalla barra laterale, con Posta in arrivo, Bozze, Inviati, Cestino ed Etichette.

OFFLINE E PRIVATA
La posta recente è salvata in un database cifrato sul tuo dispositivo: la leggi anche senza rete. Le azioni fatte offline (archivia, Stella, segna come letto) partono quando la rete torna e, se un messaggio è cambiato altrove nel frattempo, Postino te lo mostra come Conflitto e decidi tu quale modifica tenere.

Postino non ha un server suo per la posta: parla soltanto con i Provider che colleghi. Non ci sono analytics, pubblicità né raccolta automatica degli errori. Le immagini remote sono bloccate finché non scegli di vederle, e un avviso ti segnala i link il cui testo mostra un indirizzo diverso da quello vero.

CERCA IN FRETTA
I risultati compaiono mentre scrivi, dalla posta sul dispositivo. Usa da:, a: e oggetto: per cercare per mittente, destinatari e oggetto, le virgolette per una frase esatta, e i filtri per non letti, Stella, allegati, Account e date. Per la posta più vecchia la ricerca continua sul Provider.

AZIONI A SCORRIMENTO
Scorri una riga a sinistra o a destra per archiviare, segnare come letto, mettere la Stella o eliminare: scegli tu quale Azione sta in quale direzione.

NOTIFICHE CON AZIONI
Le notifiche di posta nuova sono raggruppate per Account e hanno fino a due pulsanti a tua scelta, ad esempio Archivia e Segna come letto. Di base Postino controlla la posta circa ogni 15 minuti. Se attivi le Notifiche immediate, la posta nuova arriva in tempo reale anche con Postino chiuso: in cambio resta una notifica fissa, «Postino in ascolto», e il consumo di batteria sale.

ETICHETTE, ANCHE AUTOMATICHE
Crea Etichette, anche annidate («Progetti/Postino»), e applicale ai messaggi. Con un Account Gmail puoi attivare l'Etichettatura automatica su un'Etichetta, con una descrizione: Postino la assegna da solo ai messaggi nuovi che le somigliano. Il modello gira sul tuo dispositivo e il contenuto dei messaggi non viene inviato a nessun servizio. Il modello si scarica una volta, alla prima attivazione (circa 165 MB), in Wi-Fi oppure dopo la tua conferma su rete cellulare.

SCRIVI SENZA FRETTA
Rispondi, rispondi a tutti e inoltra con la citazione del messaggio originale. Le Bozze sono salvate sul Provider, quindi le ritrovi anche in un altro client. Dopo Invia hai un attimo per annullare l'invio; se sei offline, il messaggio resta in coda e parte da solo al ritorno della rete.

IMPOSTAZIONI SU TUTTI I DISPOSITIVI
Se lo attivi, Postino tiene allineati tra i tuoi dispositivi gli Account collegati, i colori, le Azioni a scorrimento e le Etichette automatiche, in un file cifrato nello spazio riservato all'app del tuo Google Drive. La chiave resta sui tuoi dispositivi: un dispositivo nuovo si abbina inquadrando un QR o digitando un codice. Mai la posta.

SE QUALCOSA NON VA
«Segnala un problema» prepara un'email con il log degli errori: la rileggi e decidi tu se inviarla. Postino non invia nulla da solo.

Postino è disponibile in italiano e in inglese.
```

## Categoria e tag

**Crescita → Presenza sullo store → Impostazioni dello store**: tipo **App**, categoria **Comunicazione** (la categoria Play delle app email; sull'App Store è Produttività perché Apple non ha «Comunicazione» con lo stesso senso). Tag: quelli che la Console propone per «Email», fino a 5 (l'elenco dei tag si vede solo in Console, **non verificato**).

## Dettagli di contatto e informativa

| Campo | Valore |
|---|---|
| Email (obbligatoria, pubblica) | `camillo@bucciarelli.dev` |
| Sito web | https://postino.camillobucciarelli.dev |
| Telefono | vuoto (facoltativo) |
| Norme sulla privacy (**Contenuti dell'app → Norme sulla privacy**, un solo URL per l'app) | https://postino.camillobucciarelli.dev/privacy.html (rimanda alla versione inglese) |

## Grafica

| Elemento | File | Requisito di Google |
|---|---|---|
| Icona dell'app | [grafica/icona-512.png](grafica/icona-512.png) | 512 × 512, PNG a 32 bit, massimo 1024 KB, quadrata a tutto campo: angoli e ombra li mette Play ([specifiche](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)) |
| Grafica in evidenza | [grafica/grafica-in-evidenza.png](grafica/grafica-in-evidenza.png) | 1024 × 500, JPEG o PNG a 24 bit senza alfa ([asset grafici](https://support.google.com/googleplay/android-developer/answer/9866151)) |
| Screenshot del telefono | `screenshot/android/it/01…05` | vedi [screenshot.md](screenshot.md) |
| Video | nessuno | facoltativo |

Le due grafiche vengono da `tool/brand_icons.sh play` (marchio e lockup di `assets/brand/`, fondo verderame del tile).
