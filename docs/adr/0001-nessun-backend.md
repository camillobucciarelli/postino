---
status: Accettato
date: 2026-10-27
---

# Nessun backend: tutta la logica di posta sul dispositivo

Superata in parte dalla [ADR 0013](0013-observability-self-hosted.md): un endpoint di observability opt-in nella v2.
Precisata dall'[ADR 0019](0019-impostazioni-cifrate-e-credenziali-sincronizzate.md) (proposta): i token lasciano il dispositivo solo cifrati, verso lo spazio Drive dell'utente.

Postino è usato dall'autore e da pochi tester (meno di 100), senza pubblicazione sugli store. Tutta la logica di posta gira sul dispositivo e parla direttamente con i Provider: non c'è nessun server da ospitare e i token degli Account non lasciano mai il dispositivo. Il client OAuth Google è pubblicato "in produzione non verificato" (avviso di app non verificata, tetto di 100 utenti): i refresh token non scadono, a differenza della modalità Testing che li fa scadere dopo 7 giorni.

## Alternative considerate

- **Piccolo server push** (IMAP IDLE + APNs/FCM): notifiche affidabili, ma richiede hosting e custodire i token degli Account lato server.
- **Backend di sincronizzazione completo**: massimo controllo, massimo costo di gestione e superficie di sicurezza, sproporzionato per meno di 100 utenti.

## Conseguenze

- Le notifiche di nuova posta su mobile sono in ritardo o inaffidabili: dipendono dal fetch in background pianificato dal sistema operativo: su iOS è il sistema a decidere quando eseguirlo, senza frequenza garantita, e se l'utente chiude forzatamente l'app non arriva nessuna notifica.
- Il desktop compensa restando attivo nella tray / barra dei menu con connessioni aperte.
- Una Posticipa torna nella posta in arrivo solo quando uno dei dispositivi dell'utente è in esecuzione dopo il momento scelto.
- Un server push potrà essere aggiunto in seguito senza rifare il resto.
