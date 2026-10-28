---
status: Accettato
date: 2026-10-27
---

# Avatar del mittente: logo BIMI solo con DMARC e certificato verificato, altrimenti iniziali

L'Avatar del mittente mostra il logo BIMI del brand solo se: (a) i risultati di autenticazione del Provider per quel messaggio riportano DMARC pass, e (b) il record BIMI del dominio del mittente punta a un certificato VMC o CMC valido, la cui catena X.509 si verifica e il cui logo incorporato corrisponde. I loghi sono in cache per dominio per 30 giorni; in tutti gli altri casi l'Avatar mostra le iniziali su un colore derivato dall'indirizzo.

## Alternative considerate

- **Solo iniziali**: privacy perfetta, ma nessun segnale anti-phishing.
- **BIMI con DMARC pass ma senza certificato**: scartato perché un dominio simile come paypa1.com con DMARC potrebbe mostrare il logo di PayPal, aiutando il phishing.
- **Gravatar**: rivela a una terza parte l'hash di ogni indirizzo letto.

## Conseguenze

- Va implementata la validazione della catena X.509.
- Pochi mittenti hanno un VMC/CMC, quindi la maggior parte degli Avatar resta con le iniziali.
- Il download del logo rivela all'host del logo l'interesse per un dominio (non per un singolo messaggio); la cache di 30 giorni lo attenua.

## Nota: suggerimenti dei destinatari

I suggerimenti dei destinatari in composizione vengono dagli indirizzi visti nella posta sincronizzata e, per gli Account Google e Microsoft, dalla rubrica del Provider (scope di sola lettura sui contatti, aggiuntivi). Gli Account IMAP usano solo gli indirizzi visti (CardDAV fuori roadmap: [CardDAV per gli Account IMAP](https://github.com/camillobucciarelli/postino/issues/24)).
