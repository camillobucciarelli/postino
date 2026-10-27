# Postino

Client di posta personale multi-account: riunisce in un unico posto le caselle email dell'utente e gli permette di smistare i messaggi in modo rapido e uniforme, a prescindere da dove sono ospitati.

## Language

### Caselle

**Account**:
Una casella di posta collegata dall'utente, identificata da un indirizzo email e dal suo Provider. Ogni Account ha un proprio colore.
_Avoid_: Profilo, utente, casella

**Provider**:
Il servizio che ospita un Account (Gmail, Outlook, iCloud, IMAP generico).
_Avoid_: Servizio, server

**Da ricollegare**:
Lo stato di un Account il cui Provider non accetta più il suo accesso (password cambiata, accesso revocato). La sua posta resta leggibile, le azioni in attesa restano in sospeso e l'utente è invitato ad accedere di nuovo.
_Avoid_: Disconnesso, errore di login

**Posta unificata**:
La vista che fonde la posta in arrivo di tutti gli Account.
_Avoid_: Inbox globale, posta combinata

**Contatto**:
Una persona a cui l'utente può scrivere, suggerita durante la scrittura di un messaggio. Proviene dagli indirizzi visti nella posta dell'utente o dalla rubrica dell'Account sul Provider.
_Avoid_: Rubrica (è la fonte), destinatario (è un ruolo in un singolo messaggio)

### Organizzazione

**Etichetta**:
L'unico concetto con cui si organizzano i messaggi. Su Gmail un messaggio può avere molte Etichette; sui Provider basati su cartelle ne ha al massimo una, e assegnarla equivale a spostare il messaggio.
_Avoid_: Cartella, label, tag

**Stella**:
Il segno che marca un messaggio come importante. Non è la stessa cosa di Posticipa.
_Avoid_: Preferito, flag, importante

**Posticipa**:
Nascondere un messaggio fino a un momento scelto, dopo il quale torna nella posta in arrivo. Il messaggio esce dalla posta in arrivo anche sul Provider e attende nell'Etichetta **Posticipati**, così tutti i dispositivi e la webmail restano d'accordo.
_Avoid_: Snooze, rimanda, sospendi

**Posticipati**:
L'Etichetta in cui un messaggio posticipato attende sul Provider fino al suo momento di ritorno.
_Avoid_: Snoozed, in sospeso

**Conversazione**:
I messaggi di uno stesso scambio, sempre all'interno di un solo Account. Lo stesso scambio che raggiunge due Account sono due Conversazioni: nella Posta unificata compare due volte, ciascuna con il colore del proprio Account.
_Avoid_: Thread, discussione

**Invito**:
Un messaggio che propone un evento di calendario, a cui l'utente risponde Sì, Forse o No.
_Avoid_: Evento (è la cosa proposta), meeting

### Smistamento

**Sessione di smistamento**:
Una sessione concentrata in cui l'utente elabora i messaggi della posta in arrivo uno alla volta, usando le quattro Azioni configurabili a scorrimento.
_Avoid_: Triage, modalità smistamento

**Azione**:
Un'operazione su un messaggio (ad esempio Archivia, Elimina, Segna come letto, Stella, Posticipa) che l'utente associa alle quattro direzioni di scorrimento e, fino a due, ai pulsanti di una notifica di nuova posta. Di default sono Archivia e Segna come letto. Dalla notifica, Posticipa usa un momento fisso (domani alle 9:00).
_Avoid_: Gesto, comando

**Regola**:
Una condizione sui messaggi in arrivo e le Azioni che il Provider applica automaticamente quando si verifica. Appartiene a un solo Account.
_Avoid_: Filtro, automazione

### Sicurezza

**Messaggio firmato**:
Un messaggio il cui mittente è dimostrato da una firma che Postino dell'utente ha potuto verificare.
_Avoid_: Messaggio certificato, messaggio autenticato

**Messaggio cifrato**:
Un messaggio leggibile solo da chi possiede la Chiave corrispondente.
_Avoid_: Criptato, messaggio protetto

**Chiave**:
Ciò che dimostra l'identità dell'utente e gli permette di leggere i Messaggi cifrati. Le Chiavi personali non lasciano mai il dispositivo su cui sono state importate.
_Avoid_: Certificato, password, chiave privata

### Preferenze

**Impostazioni di Postino**:
Le preferenze dell'utente: Azioni per scorrimento, colori e ordine degli Account, momenti di ritorno di Posticipa e mittenti fidati. Possono seguire l'utente tra i dispositivi tramite il suo spazio Google, oppure essere esportate in un file che l'utente conserva, salva o condivide come preferisce.
_Avoid_: Config, profilo

**Mittente fidato**:
Un mittente le cui immagini remote l'utente ha scelto di mostrare sempre. Fa parte delle Impostazioni di Postino.
_Avoid_: Whitelist, contatto sicuro

## Relationships

- Un **Account** appartiene a un solo **Provider**
- Un **Provider** può ospitare molti **Account**
- Le **Etichette** appartengono a un **Account** e non sono mai condivise tra **Account**
- Una **Conversazione** appartiene a un solo **Account**
- La **Posta unificata** mostra la posta in arrivo di tutti gli **Account**
- Una **Sessione di smistamento** applica le **Azioni** ai messaggi della posta in arrivo
