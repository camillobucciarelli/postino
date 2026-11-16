# Postino

Client di posta personale multi-account: riunisce in un unico posto le caselle email dell'utente e gli permette di smistare i messaggi in modo rapido e uniforme, a prescindere da dove sono ospitati.

## Language

### Caselle

**Account**:
Una casella di posta collegata dall'utente, identificata da un indirizzo email e dal suo Provider: lo stesso indirizzo con due Provider sono due Account. Ogni Account ha un proprio colore.
_Avoid_: Profilo, utente, casella

**Provider**:
Il servizio che ospita un Account (Gmail, Outlook, iCloud, IMAP generico).
_Avoid_: Servizio, server

**Da ricollegare**:
Lo stato di un Account il cui Provider non accetta più il suo accesso (password cambiata, accesso revocato). La sua posta resta leggibile, le azioni in attesa restano in sospeso e l'utente è invitato ad accedere di nuovo.
_Avoid_: Disconnesso, errore di login

**Conflitto**:
Un'Azione fatta offline che, alla riconnessione, trova il messaggio cambiato altrove in modo diverso; resta in sospeso finché l'utente sceglie se tenere la propria modifica o quella del Provider.
_Avoid_: collisione, divergenza

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

**Etichetta automatica**:
Un'Etichetta per cui l'utente ha attivato l'Etichettatura automatica, con una descrizione facoltativa. Appartiene a un solo Account.
_Avoid_: Etichetta intelligente, smart label

**Etichettatura automatica**:
L'assegnazione, sul dispositivo, di un'Etichetta automatica ai messaggi nuovi dopo l'attivazione, al massimo una per messaggio e solo se non ne ha già una scelta dall'utente.
_Avoid_: Classificazione, smistamento automatico, tag automatici

**Ricerca**:
La ricerca nella posta, da un solo campo. Prima gira sul database locale con un indice full-text (parole che iniziano così, senza badare a maiuscole e accenti), restringendosi all'Account della vista da cui si apre; `da:`, `a:` e `oggetto:` (e `from:`, `to:`, `subject:`) cercano per mittente, destinatari e oggetto, le virgolette una frase esatta. Gli stessi operatori restringono per criteri, anche senza testo: `è:nonletto`, `è:stella`, `ha:allegato`, `dopo:AAAA-MM-GG` e `prima:AAAA-MM-GG` (giorni locali, estremi compresi), `account:nome` (parte dell'indirizzo; più nomi sono alternative); in inglese `is:unread`, `is:starred`, `has:attachment`, `after:`, `before:`. Ogni criterio guarda la Conversazione: basta un suo messaggio che lo soddisfi. Un operatore senza ancora il valore si ignora, uno con un valore che non capisce (`dopo:ieri`) resta testo. Una riga per Conversazione.
_Avoid_: Filtro, query

**Stella**:
Il segno che marca un messaggio come importante. Non è la stessa cosa di Posticipa.
_Avoid_: Preferito, flag, importante

**Spam**:
L'Etichetta di sistema dei messaggi indesiderati: su Gmail l'etichetta `SPAM`, sui Provider IMAP la cartella Junk. Un messaggio Spam non compare nella posta in arrivo né in altre viste; spostarlo nello Spam da un altro client gli cambia Etichetta, non lo cancella.
_Avoid_: Junk, posta indesiderata

**Posticipa**:
Nascondere un messaggio fino a un momento scelto, dopo il quale torna nella posta in arrivo. Il messaggio esce dalla posta in arrivo anche sul Provider e attende nell'Etichetta **Posticipati**, così tutti i dispositivi e la webmail restano d'accordo.
_Avoid_: Snooze, rimanda, sospendi

**Posticipati**:
L'Etichetta in cui un messaggio posticipato attende sul Provider fino al suo momento di ritorno.
_Avoid_: Snoozed, in sospeso

**Conversazione**:
I messaggi di uno stesso scambio, sempre all'interno di un solo Account. Lo stesso scambio che raggiunge due Account sono due Conversazioni: nella Posta unificata compare due volte, ciascuna con il colore del proprio Account.
_Avoid_: Thread, discussione

**Bozza**:
Un messaggio non ancora inviato, salvato nella cartella Bozze del Provider del suo Account, così da poterlo riprendere su qualsiasi dispositivo o in un altro client. Appartiene a un solo Account; se viene modificata in due posti diversi nasce un Conflitto.

**Citazione**:
Il messaggio originale riportato sotto il testo nuovo di un Rispondi o Inoltra: la riga «Il giorno <data>, <Nome> <email> ha scritto:» seguita dal corpo originale, modificabile nell'editor.
_Avoid_: Quote, testo citato (è la parte ripiegata di un messaggio ricevuto)

**Annulla invio**:
La breve attesa dopo Invia durante la quale l'utente può ritirare il messaggio e tornare a modificarlo; trascorsa l'attesa il messaggio parte anche se l'app è stata chiusa.
_Avoid_: Undo send, ripensamento

**Inviati**:
La cartella del Provider con i messaggi spediti dall'Account. Vi compare subito anche il messaggio in coda (Annulla invio, offline), con il suo stato, finché non è partito.
_Avoid_: Sent, posta inviata

**Coda d'uscita**:
La coda locale dei messaggi da inviare: ogni voce porta il MIME già costruito e il Message-ID; parte dopo l'attesa di Annulla invio, anche offline al ritorno della rete.
_Avoid_: Outbox, posta in uscita

**Invito**:
Un messaggio che propone un evento di calendario, a cui l'utente risponde Sì, Forse o No.
_Avoid_: Evento (è la cosa proposta), meeting

### Smistamento

**Sessione di smistamento**:
Una sessione concentrata in cui l'utente elabora i messaggi della posta in arrivo uno alla volta, usando le quattro Azioni configurabili a scorrimento. Mostra un messaggio alla volta come una scheda; dopo la stessa Azione applicata due volte allo stesso mittente propone di crearne una Regola, già compilata.
_Avoid_: Triage, modalità smistamento

**Azione**:
Un'operazione su un messaggio (ad esempio Archivia, Elimina, Segna come letto, Stella, Posticipa) che l'utente associa alle quattro direzioni di scorrimento e, fino a due, ai pulsanti di una notifica di nuova posta. Di default sono Archivia e Segna come letto. Dalla notifica, Posticipa usa un momento fisso (domani alle 9:00).
_Avoid_: Gesto, comando

**Regola**:
Una condizione sui messaggi in arrivo e le Azioni che il Provider applica automaticamente quando si verifica. Appartiene a un solo Account.
_Avoid_: Filtro, automazione

**Etichettatura automatica**:
L'assegnazione, decisa sul dispositivo, di un'Etichetta automatica a un messaggio appena arrivato in base al suo contenuto e agli esempi dell'Account; al massimo un'Etichetta per messaggio, e non avviene se il messaggio ha già un'Etichetta dell'utente. Differisce dalla Regola: la Regola ha una condizione esplicita ed è applicata dal Provider.
_Avoid_: Classificazione, smistamento automatico, filtro intelligente, categoria

**Etichetta automatica**:
Un'Etichetta per cui l'utente ha attivato l'Etichettatura automatica, con una descrizione facoltativa che ne spiega il significato. Non è una Regola: non ha una condizione esplicita e non la applica il Provider; la configurazione (attiva, descrizione) è un'Impostazione di Postino.
_Avoid_: Categoria

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
Le preferenze dell'utente: Azioni per scorrimento, colori e ordine degli Account, momenti di ritorno di Posticipa, mittenti fidati, configurazione delle Etichette automatiche e, cifrate, le credenziali degli Account. Seguono l'utente tra i dispositivi tramite l'Account di sincronizzazione, oppure si esportano in un file che l'utente conserva, salva o condivide come preferisce.
_Avoid_: Config, profilo

**Account di sincronizzazione**:
L'Account scelto alla voce "Sincronizza su…" nel cui spazio Google (Drive) stanno le Impostazioni di Postino. È un'Impostazione del dispositivo; senza una scelta le Impostazioni di Postino restano locali.
_Avoid_: Account principale, Account di backup

**Chiave di sincronizzazione**:
Il segreto con cui le Impostazioni di Postino sono cifrate nello spazio Google dell'Account di sincronizzazione. Passa da un dispositivo all'altro solo con l'Abbinamento, mai attraverso Drive. Non è una Chiave: non identifica l'utente e non riguarda i Messaggi cifrati.
_Avoid_: Password di sincronizzazione, chiave di backup

**Abbinamento**:
Il passaggio della Chiave di sincronizzazione da un dispositivo che la possiede a uno nuovo, inquadrando un QR o digitando un codice. Un dispositivo non abbinato non legge né scrive le Impostazioni di Postino sincronizzate.
_Avoid_: Pairing, associazione, collegamento (si collega un Account, si abbina un dispositivo)

**Impostazioni del dispositivo**:
Le preferenze che valgono solo per un dispositivo e non si sincronizzano tra dispositivi, a differenza delle Impostazioni di Postino. Ad esempio le Notifiche immediate, l'avvio al login, il tema e l'Observability.

**Notifiche immediate**:
Su Android, la scelta di ricevere la posta nuova in tempo reale al prezzo di una notifica fissa e dell'esclusione dall'ottimizzazione batteria. Senza, la posta nuova si controlla circa ogni 15 minuti.

**Mittente fidato**:
Un mittente le cui immagini remote l'utente ha scelto di mostrare sempre. Fa parte delle Impostazioni di Postino.
_Avoid_: Whitelist, contatto sicuro

**Segnalazione di un problema**:
L'email che un utente manda all'autore di Postino con il log degli errori allegato, preparata da Postino al riavvio dopo un crash o su richiesta. L'utente la rilegge e decide se inviarla.
_Avoid_: Crash report, telemetria

**Observability**:
L'invio opt-in di errori, metriche tecniche e metriche d'uso a uno stack ospitato dall'autore, dalla v2. Non contiene mai contenuti di posta.
_Avoid_: Telemetria, analytics

## Relationships

- Un **Account** appartiene a un solo **Provider**
- Un **Provider** può ospitare molti **Account**
- Le **Etichette** appartengono a un **Account** e non sono mai condivise tra **Account**
- Un'**Etichetta automatica** appartiene a un **Account**, come ogni **Etichetta**; l'**Etichettatura automatica** impara solo dagli esempi di quell'**Account**
- Una **Conversazione** appartiene a un solo **Account**
- Una **Bozza** appartiene a un solo **Account**
- La **Posta unificata** mostra la posta in arrivo di tutti gli **Account**
- Una **Sessione di smistamento** applica le **Azioni** ai messaggi della posta in arrivo
