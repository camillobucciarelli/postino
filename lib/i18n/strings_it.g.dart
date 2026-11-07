///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsIt = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.it,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <it>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// it: 'Postino'
	String get appTitle => 'Postino';

	/// it: 'Posta unificata'
	String get postaUnificata => 'Posta unificata';

	/// it: 'Posta in arrivo'
	String get postaInArrivo => 'Posta in arrivo';

	/// it: 'Account'
	String get account => 'Account';

	/// it: '(one) {$n account} (other) {$n account}'
	String accountCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		one: '${n} account',
		other: '${n} account',
	);

	late final Translations$sidebar$it sidebar = Translations$sidebar$it.internal(_root);
	late final Translations$listWidth$it listWidth = Translations$listWidth$it.internal(_root);

	/// it: 'Etichette'
	String get etichette => 'Etichette';

	late final Translations$onboarding$it onboarding = Translations$onboarding$it.internal(_root);
	late final Translations$daRicollegare$it daRicollegare = Translations$daRicollegare$it.internal(_root);
	late final Translations$connect$it connect = Translations$connect$it.internal(_root);
	late final Translations$offline$it offline = Translations$offline$it.internal(_root);
	late final Translations$list$it list = Translations$list$it.internal(_root);
	late final Translations$conversazione$it conversazione = Translations$conversazione$it.internal(_root);
	late final Translations$composizione$it composizione = Translations$composizione$it.internal(_root);
	late final Translations$bozze$it bozze = Translations$bozze$it.internal(_root);
	late final Translations$inviati$it inviati = Translations$inviati$it.internal(_root);
	late final Translations$impostazioni$it impostazioni = Translations$impostazioni$it.internal(_root);
	late final Translations$segnalazione$it segnalazione = Translations$segnalazione$it.internal(_root);
	late final Translations$tray$it tray = Translations$tray$it.internal(_root);
	late final Translations$selettoreEtichette$it selettoreEtichette = Translations$selettoreEtichette$it.internal(_root);
	late final Translations$etichetteAutomatiche$it etichetteAutomatiche = Translations$etichetteAutomatiche$it.internal(_root);
	late final Translations$notifiche$it notifiche = Translations$notifiche$it.internal(_root);
	late final Translations$conflitti$it conflitti = Translations$conflitti$it.internal(_root);
	late final Translations$azioni$it azioni = Translations$azioni$it.internal(_root);
	late final Translations$scorrimento$it scorrimento = Translations$scorrimento$it.internal(_root);
	late final Translations$passwordForm$it passwordForm = Translations$passwordForm$it.internal(_root);
	late final Translations$accounts$it accounts = Translations$accounts$it.internal(_root);
}

// Path: sidebar
class Translations$sidebar$it {
	Translations$sidebar$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Chiudi la barra laterale'
	String get close => 'Chiudi la barra laterale';

	/// it: 'Apri la barra laterale'
	String get open => 'Apri la barra laterale';
}

// Path: listWidth
class Translations$listWidth$it {
	Translations$listWidth$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Larghezza lista'
	String get label => 'Larghezza lista';

	/// it: '$px pixel'
	String value({required Object px}) => '${px} pixel';
}

// Path: onboarding
class Translations$onboarding$it {
	Translations$onboarding$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Tutte le tue caselle in un posto solo.'
	String get body => 'Tutte le tue caselle in un posto solo.';

	/// it: 'Collega Gmail'
	String get connectGmail => 'Collega Gmail';

	/// it: 'Collega iCloud'
	String get connectIcloud => 'Collega iCloud';

	/// it: 'Altro IMAP'
	String get connectImap => 'Altro IMAP';
}

// Path: daRicollegare
class Translations$daRicollegare$it {
	Translations$daRicollegare$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: '$name è da ricollegare'
	String title({required Object name}) => '${name} è da ricollegare';

	/// it: 'Google non accetta più l'accesso. La posta resta leggibile ma non si aggiorna finché non accedi.'
	String get message => 'Google non accetta più l\'accesso. La posta resta leggibile ma non si aggiorna finché non accedi.';

	/// it: 'Accedi'
	String get signIn => 'Accedi';

	/// it: 'Da ricollegare'
	String get status => 'Da ricollegare';

	/// it: 'Il server non accetta più la password. La posta resta leggibile ma non si aggiorna finché non accedi.'
	String get passwordMessage => 'Il server non accetta più la password. La posta resta leggibile ma non si aggiorna finché non accedi.';
}

// Path: connect
class Translations$connect$it {
	Translations$connect$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Collegamento non riuscito'
	String get title => 'Collegamento non riuscito';

	/// it: 'Manca $setting: avvia Postino con --dart-define=$setting=… (vedi README).'
	String missingSetting({required Object setting}) => 'Manca ${setting}: avvia Postino con --dart-define=${setting}=… (vedi README).';

	/// it: 'Nessuna connessione: riprova quando sei online.'
	String get offline => 'Nessuna connessione: riprova quando sei online.';

	/// it: 'Serve l'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.'
	String get missingPermission => 'Serve l\'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.';

	/// it: 'Hai scelto un altro account Google: per ricollegare $address scegli quell'account.'
	String wrongAccount({required Object address}) => 'Hai scelto un altro account Google: per ricollegare ${address} scegli quell\'account.';

	/// it: 'Qualcosa è andato storto: riprova.'
	String get failed => 'Qualcosa è andato storto: riprova.';

	/// it: 'Questo indirizzo è già collegato come un altro Account.'
	String get alreadyConnected => 'Questo indirizzo è già collegato come un altro Account.';
}

// Path: offline
class Translations$offline$it {
	Translations$offline$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Sei offline'
	String get title => 'Sei offline';

	/// it: 'La posta si aggiornerà al ritorno della rete.'
	String get message => 'La posta si aggiornerà al ritorno della rete.';
}

// Path: list
class Translations$list$it {
	Translations$list$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Caricamento dei messaggi'
	String get loading => 'Caricamento dei messaggi';

	/// it: 'Niente di nuovo'
	String get emptyTitle => 'Niente di nuovo';

	/// it: 'I messaggi compaiono qui appena arrivano.'
	String get emptyBody => 'I messaggi compaiono qui appena arrivano.';

	/// it: 'Ieri'
	String get yesterday => 'Ieri';

	/// it: 'Non letto'
	String get unread => 'Non letto';

	/// it: 'con Stella'
	String get starred => 'con Stella';

	/// it: 'account $name'
	String account({required Object name}) => 'account ${name}';

	/// it: '(one) {$n messaggio} (other) {$n messaggi}'
	String messages({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		one: '${n} messaggio',
		other: '${n} messaggi',
	);
}

// Path: conversazione
class Translations$conversazione$it {
	Translations$conversazione$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Seleziona una Conversazione'
	String get selectTitle => 'Seleziona una Conversazione';

	/// it: 'Scegli una Conversazione dalla lista per leggerla qui.'
	String get selectBody => 'Scegli una Conversazione dalla lista per leggerla qui.';

	/// it: 'a $recipients'
	String to({required Object recipients}) => 'a ${recipients}';

	/// it: 'Caricamento…'
	String get loading => 'Caricamento…';

	/// it: 'Corpo non disponibile offline'
	String get offline => 'Corpo non disponibile offline';

	/// it: 'Corpo non disponibile'
	String get failed => 'Corpo non disponibile';

	/// it: 'Riprova'
	String get retry => 'Riprova';

	/// it: 'Immagini remote bloccate'
	String get imagesBlocked => 'Immagini remote bloccate';

	/// it: 'Mostra immagini'
	String get showImages => 'Mostra immagini';

	/// it: 'Sempre da questo mittente'
	String get alwaysFromSender => 'Sempre da questo mittente';

	/// it: 'me'
	String get me => 'me';

	/// it: 'Da'
	String get from => 'Da';

	/// it: 'A'
	String get toLabel => 'A';

	/// it: 'Data'
	String get date => 'Data';

	/// it: 'Ricevuto su'
	String get receivedOn => 'Ricevuto su';

	/// it: 'Caricarle direbbe al mittente che hai aperto il messaggio.'
	String get imagesBlockedBody => 'Caricarle direbbe al mittente che hai aperto il messaggio.';

	/// it: 'a $recipients, cc $cc'
	String toCc({required Object recipients, required Object cc}) => 'a ${recipients}, cc ${cc}';

	/// it: 'Cc'
	String get cc => 'Cc';

	/// it: 'Mostra testo citato'
	String get showQuoted => 'Mostra testo citato';

	/// it: 'Immagine bloccata'
	String get blockedImage => 'Immagine bloccata';

	/// it: '(one) {$subject, $n messaggio} (other) {$subject, $n messaggi}'
	String announcement({required num n, required Object subject}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		one: '${subject}, ${n} messaggio',
		other: '${subject}, ${n} messaggi',
	);

	/// it: 'Importante'
	String get important => 'Importante';

	/// it: 'Apri'
	String get attachmentOpen => 'Apri';

	/// it: 'Scaricamento… $percent%'
	String attachmentDownloading({required Object percent}) => 'Scaricamento… ${percent}%';

	/// it: 'Annulla scaricamento'
	String get attachmentCancel => 'Annulla scaricamento';

	/// it: 'Offline: allegato non ancora scaricato'
	String get attachmentOffline => 'Offline: allegato non ancora scaricato';

	/// it: 'Scaricamento non riuscito'
	String get attachmentFailed => 'Scaricamento non riuscito';

	/// it: 'Altre azioni'
	String get attachmentMore => 'Altre azioni';

	/// it: 'Salva…'
	String get attachmentSave => 'Salva…';

	/// it: 'Salvataggio non riuscito'
	String get attachmentSaveFailed => 'Salvataggio non riuscito';

	/// it: 'Eseguibile: non si apre da Postino. Salvalo solo se ti fidi del mittente'
	String get attachmentExecutable => 'Eseguibile: non si apre da Postino. Salvalo solo se ti fidi del mittente';

	/// it: 'Allegato senza nome'
	String get attachmentUntitled => 'Allegato senza nome';

	/// it: 'Rispondi'
	String get reply => 'Rispondi';

	/// it: 'Rispondi a tutti'
	String get replyAll => 'Rispondi a tutti';

	/// it: 'Inoltra'
	String get forward => 'Inoltra';

	/// it: 'Impossibile inoltrare: messaggio non scaricato'
	String get forwardUnavailable => 'Impossibile inoltrare: messaggio non scaricato';

	/// it: 'Azioni del messaggio'
	String get messageActions => 'Azioni del messaggio';

	/// it: 'Vedi originale'
	String get viewOriginal => 'Vedi originale';

	/// it: 'Messaggio originale'
	String get originalTitle => 'Messaggio originale';

	/// it: 'Questo link porta a un altro sito'
	String get linkWarningTitle => 'Questo link porta a un altro sito';

	/// it: 'Il testo del link mostra un indirizzo diverso da quello vero. Se lo apri, vai su $domain.'
	String linkWarningBody({required Object domain}) => 'Il testo del link mostra un indirizzo diverso da quello vero. Se lo apri, vai su ${domain}.';

	/// it: 'Non si può verificare dove porta questo link. Se lo apri, vai su $domain.'
	String linkUnverifiedBody({required Object domain}) => 'Non si può verificare dove porta questo link. Se lo apri, vai su ${domain}.';

	/// it: 'Il nome del sito usa caratteri speciali (punycode): potrebbe imitarne un altro.'
	String get linkWarningPunycode => 'Il nome del sito usa caratteri speciali (punycode): potrebbe imitarne un altro.';

	/// it: 'Apri il link'
	String get linkOpen => 'Apri il link';

	/// it: 'Non aprire'
	String get linkCancel => 'Non aprire';
}

// Path: composizione
class Translations$composizione$it {
	Translations$composizione$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Nuovo messaggio'
	String get title => 'Nuovo messaggio';

	/// it: 'Scrivi'
	String get write => 'Scrivi';

	/// it: 'Da'
	String get from => 'Da';

	/// it: 'A'
	String get to => 'A';

	/// it: 'Cc'
	String get cc => 'Cc';

	/// it: 'Ccn'
	String get bcc => 'Ccn';

	/// it: 'Oggetto'
	String get subject => 'Oggetto';

	/// it: 'Scrivi il messaggio'
	String get body => 'Scrivi il messaggio';

	/// it: 'Chiudi'
	String get close => 'Chiudi';

	/// it: 'Grassetto'
	String get bold => 'Grassetto';

	/// it: 'Corsivo'
	String get italic => 'Corsivo';

	/// it: 'Sottolineato'
	String get underline => 'Sottolineato';

	/// it: 'Barrato'
	String get strikethrough => 'Barrato';

	/// it: 'Link'
	String get link => 'Link';

	/// it: 'Elenco puntato'
	String get bulletList => 'Elenco puntato';

	/// it: 'Elenco numerato'
	String get numberedList => 'Elenco numerato';

	/// it: 'Indirizzo del link'
	String get linkUrl => 'Indirizzo del link';

	/// it: 'Inserisci'
	String get insert => 'Inserisci';

	/// it: 'Annulla'
	String get cancel => 'Annulla';

	/// it: 'Corpo del messaggio'
	String get editor => 'Corpo del messaggio';

	/// it: 'Bozza non trovata'
	String get draftNotFound => 'Bozza non trovata';

	/// it: 'Questa Bozza ha allegati: modificala dal client che l'ha creata'
	String get draftWithAttachments => 'Questa Bozza ha allegati: modificala dal client che l\'ha creata';

	/// it: 'Questa Bozza è una risposta: modificala dal client che l'ha creata'
	String get draftReply => 'Questa Bozza è una risposta: modificala dal client che l\'ha creata';

	/// it: 'Invia'
	String get send => 'Invia';

	/// it: 'In attesa d'invio'
	String get queued => 'In attesa d\'invio';

	/// it: 'Annulla'
	String get undo => 'Annulla';

	/// it: 'Il messaggio supera il limite di $mb MB di Gmail'
	String tooLarge({required Object mb}) => 'Il messaggio supera il limite di ${mb} MB di Gmail';

	/// it: 'Invio non riuscito: riprova'
	String get sendFailed => 'Invio non riuscito: riprova';

	/// it: 'Sei offline: gli allegati dell'inoltro non sono ancora scaricati, riprova in rete'
	String get offlineAttachments => 'Sei offline: gli allegati dell\'inoltro non sono ancora scaricati, riprova in rete';

	/// it: 'Aggiungi almeno un destinatario'
	String get noRecipient => 'Aggiungi almeno un destinatario';

	/// it: 'Allegati'
	String get forwardedAttachments => 'Allegati';
}

// Path: bozze
class Translations$bozze$it {
	Translations$bozze$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Bozze'
	String get title => 'Bozze';

	/// it: 'Nessuna bozza'
	String get emptyTitle => 'Nessuna bozza';

	/// it: 'Le bozze che scrivi restano qui finché non le invii.'
	String get emptyBody => 'Le bozze che scrivi restano qui finché non le invii.';
}

// Path: inviati
class Translations$inviati$it {
	Translations$inviati$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Inviati'
	String get title => 'Inviati';

	/// it: 'In attesa d'invio'
	String get waiting => 'In attesa d\'invio';

	/// it: 'In uscita, in attesa di rete'
	String get offline => 'In uscita, in attesa di rete';

	/// it: 'Invio non riuscito'
	String get failed => 'Invio non riuscito';

	/// it: 'Nessun messaggio inviato'
	String get emptyTitle => 'Nessun messaggio inviato';

	/// it: 'I messaggi che invii compaiono qui.'
	String get emptyBody => 'I messaggi che invii compaiono qui.';
}

// Path: impostazioni
class Translations$impostazioni$it {
	Translations$impostazioni$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Impostazioni'
	String get title => 'Impostazioni';

	/// it: 'Dispositivo'
	String get deviceSection => 'Dispositivo';

	/// it: 'Impostazioni del dispositivo'
	String get device => 'Impostazioni del dispositivo';

	/// it: 'Avvio al login'
	String get launchAtLogin => 'Avvio al login';

	/// it: 'Postino si apre quando accedi al computer e resta nella tray, così la posta continua ad arrivare.'
	String get launchAtLoginBody => 'Postino si apre quando accedi al computer e resta nella tray, così la posta continua ad arrivare.';

	/// it: 'Il sistema non ha accettato la modifica. Riprova, o controlla gli elementi di login nelle impostazioni di sistema.'
	String get launchAtLoginFailed => 'Il sistema non ha accettato la modifica. Riprova, o controlla gli elementi di login nelle impostazioni di sistema.';

	/// it: 'Cerca aggiornamenti'
	String get checkForUpdates => 'Cerca aggiornamenti';

	/// it: 'Cerca subito una nuova versione di Postino.'
	String get checkForUpdatesBody => 'Cerca subito una nuova versione di Postino.';

	/// it: 'Sincronizzazione'
	String get syncSection => 'Sincronizzazione';

	/// it: 'Sincronizza su…'
	String get syncTitle => 'Sincronizza su…';

	/// it: 'Nessuno'
	String get syncNone => 'Nessuno';

	/// it: 'Le Impostazioni di Postino (per esempio le Etichette automatiche) vengono salvate in un file nascosto nel Google Drive dell'Account scelto, senza credenziali. Postino chiede a Google l'accesso a quello spazio nascosto di Drive, non ai tuoi file.'
	String get syncBody => 'Le Impostazioni di Postino (per esempio le Etichette automatiche) vengono salvate in un file nascosto nel Google Drive dell\'Account scelto, senza credenziali. Postino chiede a Google l\'accesso a quello spazio nascosto di Drive, non ai tuoi file.';

	/// it: 'Sincronizza le Impostazioni su'
	String get syncChooserTitle => 'Sincronizza le Impostazioni su';

	/// it: 'Annulla'
	String get syncCancel => 'Annulla';

	/// it: 'Accesso a Drive in corso…'
	String get syncBusy => 'Accesso a Drive in corso…';

	/// it: 'Google non ha concesso l'accesso allo spazio nascosto di Drive. La sincronizzazione resta com'era.'
	String get syncDenied => 'Google non ha concesso l\'accesso allo spazio nascosto di Drive. La sincronizzazione resta com\'era.';

	/// it: 'Hai scelto un altro account Google. Scegli $address.'
	String syncWrongAccount({required Object address}) => 'Hai scelto un altro account Google. Scegli ${address}.';

	/// it: 'Sei offline. Riprova quando torna la rete.'
	String get syncOffline => 'Sei offline. Riprova quando torna la rete.';

	/// it: 'Non è stato possibile collegare Drive. Riprova.'
	String get syncFailed => 'Non è stato possibile collegare Drive. Riprova.';
}

// Path: segnalazione
class Translations$segnalazione$it {
	Translations$segnalazione$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Segnala un problema'
	String get action => 'Segnala un problema';

	/// it: 'Problema in Postino'
	String get subject => 'Problema in Postino';

	/// it: 'Descrivi qui cosa è andato storto. Sotto trovi il log degli errori di Postino: senza password né token, rileggilo prima di inviare.'
	String get intro => 'Descrivi qui cosa è andato storto. Sotto trovi il log degli errori di Postino: senza password né token, rileggilo prima di inviare.';

	/// it: 'Postino si è chiuso in modo imprevisto'
	String get crashTitle => 'Postino si è chiuso in modo imprevisto';

	/// it: 'Vuoi segnalare il problema? Si apre una bozza con il log degli errori: la rileggi e decidi tu se inviarla.'
	String get crashBody => 'Vuoi segnalare il problema? Si apre una bozza con il log degli errori: la rileggi e decidi tu se inviarla.';

	/// it: 'Segnala'
	String get crashConfirm => 'Segnala';

	/// it: 'Non ora'
	String get crashDismiss => 'Non ora';
}

// Path: tray
class Translations$tray$it {
	Translations$tray$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Apri Postino'
	String get open => 'Apri Postino';

	/// it: 'Esci'
	String get quit => 'Esci';
}

// Path: selettoreEtichette
class Translations$selettoreEtichette$it {
	Translations$selettoreEtichette$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Etichette'
	String get button => 'Etichette';

	/// it: 'Etichette…'
	String get menuItem => 'Etichette…';

	/// it: 'Chiudi le Etichette'
	String get close => 'Chiudi le Etichette';

	/// it: 'Cerca o crea un'Etichetta'
	String get search => 'Cerca o crea un\'Etichetta';

	/// it: 'Usa «/» per annidarla, es. Progetti/Postino.'
	String get nestHelp => 'Usa «/» per annidarla, es. Progetti/Postino.';

	/// it: 'Crea «$name»'
	String create({required Object name}) => 'Crea «${name}»';

	/// it: '(zero) {Etichette, nessuna selezionata} (one) {Etichette, $n selezionata} (other) {Etichette, $n selezionate}'
	String selected({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		zero: 'Etichette, nessuna selezionata',
		one: 'Etichette, ${n} selezionata',
		other: 'Etichette, ${n} selezionate',
	);

	/// it: 'Nessuna Etichetta'
	String get empty => 'Nessuna Etichetta';

	/// it: 'Etichetta «$name» tolta'
	String removed({required Object name}) => 'Etichetta «${name}» tolta';

	/// it: 'Annulla'
	String get undo => 'Annulla';

	/// it: 'Togli Etichetta $name'
	String remove({required Object name}) => 'Togli Etichetta ${name}';

	/// it: 'Scrivi un nome per l'Etichetta.'
	String get errorEmpty => 'Scrivi un nome per l\'Etichetta.';

	/// it: 'Ogni livello ha bisogno di un nome: niente «/» all'inizio, alla fine o doppie.'
	String get errorEmptyLevel => 'Ogni livello ha bisogno di un nome: niente «/» all\'inizio, alla fine o doppie.';

	/// it: 'Esiste già un'Etichetta con questo nome.'
	String get errorDuplicate => 'Esiste già un\'Etichetta con questo nome.';
}

// Path: etichetteAutomatiche
class Translations$etichetteAutomatiche$it {
	Translations$etichetteAutomatiche$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Etichette automatiche'
	String get title => 'Etichette automatiche';

	/// it: 'Impostazioni · $account'
	String page({required Object account}) => 'Impostazioni · ${account}';

	/// it: 'Un modello che gira sul tuo dispositivo assegna le Etichette alle email in arrivo. Vale solo per le email nuove arrivate dopo l'attivazione. Ogni email riceve al massimo un'Etichetta, e quelle che ne hanno già una vengono saltate. L'Etichetta viene scritta su Gmail.'
	String get intro => 'Un modello che gira sul tuo dispositivo assegna le Etichette alle email in arrivo.\nVale solo per le email nuove arrivate dopo l\'attivazione.\nOgni email riceve al massimo un\'Etichetta, e quelle che ne hanno già una vengono saltate.\nL\'Etichetta viene scritta su Gmail.';

	/// it: 'Etichette'
	String get labels => 'Etichette';

	/// it: 'Nessuna Etichetta: creane una per iniziare.'
	String get empty => 'Nessuna Etichetta: creane una per iniziare.';

	/// it: 'Automatica'
	String get automatic => 'Automatica';

	/// it: 'Descrizione (facoltativa)'
	String get description => 'Descrizione (facoltativa)';

	/// it: 'Descrivi che email ci vanno, es. fatture e ricevute dei fornitori'
	String get descriptionHelp => 'Descrivi che email ci vanno, es. fatture e ricevute dei fornitori';

	/// it: 'Descrizione salvata'
	String get descriptionSaved => 'Descrizione salvata';

	/// it: 'Crea Etichetta'
	String get create => 'Crea Etichetta';

	/// it: 'Crea Etichetta'
	String get createTitle => 'Crea Etichetta';

	/// it: 'Nome dell'Etichetta'
	String get createName => 'Nome dell\'Etichetta';

	/// it: 'Usa «/» per annidarla, es. Progetti/Postino.'
	String get createHelp => 'Usa «/» per annidarla, es. Progetti/Postino.';

	/// it: 'Crea'
	String get createAction => 'Crea';

	/// it: 'Annulla'
	String get createCancel => 'Annulla';

	/// it: 'Non è stato possibile creare l'Etichetta. Controlla la connessione e riprova.'
	String get createFailed => 'Non è stato possibile creare l\'Etichetta. Controlla la connessione e riprova.';

	/// it: 'Scrivi un nome per l'Etichetta.'
	String get errorEmpty => 'Scrivi un nome per l\'Etichetta.';

	/// it: 'Ogni livello ha bisogno di un nome: niente «/» all'inizio, alla fine o doppie.'
	String get errorEmptyLevel => 'Ogni livello ha bisogno di un nome: niente «/» all\'inizio, alla fine o doppie.';

	/// it: 'Esiste già un'Etichetta con questo nome.'
	String get errorDuplicate => 'Esiste già un\'Etichetta con questo nome.';

	late final Translations$etichetteAutomatiche$model$it model = Translations$etichetteAutomatiche$model$it.internal(_root);
}

// Path: notifiche
class Translations$notifiche$it {
	Translations$notifiche$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Posta nuova'
	String get channel => 'Posta nuova';

	/// it: 'Apri'
	String get open => 'Apri';

	/// it: 'Notifiche della posta nuova'
	String get permissionTitle => 'Notifiche della posta nuova';

	/// it: 'Postino ti avvisa quando arriva un messaggio, con mittente, oggetto e anteprima. Il sistema ti chiederà il permesso.'
	String get permissionBody => 'Postino ti avvisa quando arriva un messaggio, con mittente, oggetto e anteprima. Il sistema ti chiederà il permesso.';

	/// it: 'Continua'
	String get permissionAllow => 'Continua';

	/// it: 'Non ora'
	String get permissionLater => 'Non ora';
}

// Path: conflitti
class Translations$conflitti$it {
	Translations$conflitti$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: '(one) {$n conflitto} (other) {$n conflitti}'
	String bannerTitle({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		one: '${n} conflitto',
		other: '${n} conflitti',
	);

	/// it: 'Hai cambiato dei messaggi offline e nel frattempo sono cambiati anche altrove.'
	String get bannerMessage => 'Hai cambiato dei messaggi offline e nel frattempo sono cambiati anche altrove.';

	/// it: 'Vedi'
	String get open => 'Vedi';

	/// it: 'Conflitti'
	String get title => 'Conflitti';

	/// it: 'Nessun conflitto'
	String get emptyTitle => 'Nessun conflitto';

	/// it: 'Quando un messaggio cambia in due posti, lo trovi qui.'
	String get emptyBody => 'Quando un messaggio cambia in due posti, lo trovi qui.';

	/// it: 'La tua'
	String get keepMine => 'La tua';

	/// it: 'Del Provider'
	String get keepProvider => 'Del Provider';

	/// it: 'La tua: $value'
	String mine({required Object value}) => 'La tua: ${value}';

	/// it: 'Provider: $value'
	String provider({required Object value}) => 'Provider: ${value}';

	/// it: 'In conflitto'
	String get sign => 'In conflitto';

	/// it: 'In conflitto: $sender, $time'
	String signFor({required Object sender, required Object time}) => 'In conflitto: ${sender}, ${time}';

	/// it: 'Questo messaggio è cambiato anche altrove. Qui vedi la tua versione.'
	String get signMessage => 'Questo messaggio è cambiato anche altrove. Qui vedi la tua versione.';

	/// it: 'account $name'
	String account({required Object name}) => 'account ${name}';

	/// it: '(senza oggetto)'
	String get noSubject => '(senza oggetto)';

	/// it: 'Bozza'
	String get draft => 'Bozza';

	/// it: 'La tua versione: oggetto $subject, testo $body'
	String draftMine({required Object subject, required Object body}) => 'La tua versione: oggetto ${subject}, testo ${body}';

	/// it: 'Versione del Provider: oggetto $subject, testo $body'
	String draftProvider({required Object subject, required Object body}) => 'Versione del Provider: oggetto ${subject}, testo ${body}';

	late final Translations$conflitti$values$it values = Translations$conflitti$values$it.internal(_root);
}

// Path: azioni
class Translations$azioni$it {
	Translations$azioni$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Archivia'
	String get archive => 'Archivia';

	/// it: 'Elimina'
	String get delete => 'Elimina';

	/// it: 'Aggiungi stella'
	String get star => 'Aggiungi stella';

	/// it: 'Togli stella'
	String get unstar => 'Togli stella';

	/// it: 'Segna come letto'
	String get markRead => 'Segna come letto';

	/// it: 'Segna come non letto'
	String get markUnread => 'Segna come non letto';

	/// it: 'Conversazione archiviata'
	String get archived => 'Conversazione archiviata';

	/// it: 'Conversazione spostata nel Cestino'
	String get deleted => 'Conversazione spostata nel Cestino';

	/// it: 'Etichetta «$name» applicata'
	String labelApplied({required Object name}) => 'Etichetta «${name}» applicata';

	/// it: 'Annulla'
	String get undo => 'Annulla';

	/// it: 'Altre azioni'
	String get more => 'Altre azioni';

	/// it: 'Applica Etichetta'
	String get applyLabel => 'Applica Etichetta';
}

// Path: scorrimento
class Translations$scorrimento$it {
	Translations$scorrimento$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Azioni per scorrimento'
	String get title => 'Azioni per scorrimento';

	/// it: 'Scorrendo una riga della lista si esegue un'Azione. La scelta vale per tutti gli Account.'
	String get intro => 'Scorrendo una riga della lista si esegue un\'Azione. La scelta vale per tutti gli Account.';

	/// it: 'Scorrimento a sinistra'
	String get left => 'Scorrimento a sinistra';

	/// it: 'Scorrimento a destra'
	String get right => 'Scorrimento a destra';

	/// it: 'Segna come letto/non letto'
	String get markRead => 'Segna come letto/non letto';

	/// it: 'Stella'
	String get star => 'Stella';
}

// Path: passwordForm
class Translations$passwordForm$it {
	Translations$passwordForm$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Collega iCloud'
	String get icloudTitle => 'Collega iCloud';

	/// it: 'Collega un Account IMAP'
	String get imapTitle => 'Collega un Account IMAP';

	/// it: 'Ricollega l'Account'
	String get reconnectTitle => 'Ricollega l\'Account';

	/// it: 'Indirizzo email'
	String get address => 'Indirizzo email';

	/// it: 'Password'
	String get password => 'Password';

	/// it: 'Password per app'
	String get appPassword => 'Password per app';

	/// it: 'iCloud chiede una password per app, non la password del tuo Apple Account.'
	String get icloudHelp => 'iCloud chiede una password per app, non la password del tuo Apple Account.';

	/// it: 'Come creare una password per app'
	String get appleLink => 'Come creare una password per app';

	/// it: 'Impostazione manuale dei server'
	String get manual => 'Impostazione manuale dei server';

	/// it: 'Server IMAP (posta in arrivo)'
	String get imapServer => 'Server IMAP (posta in arrivo)';

	/// it: 'Server SMTP (posta in uscita)'
	String get smtpServer => 'Server SMTP (posta in uscita)';

	/// it: 'Host'
	String get host => 'Host';

	/// it: 'Porta'
	String get port => 'Porta';

	/// it: 'SSL/TLS'
	String get ssl => 'SSL/TLS';

	/// it: 'STARTTLS'
	String get starttls => 'STARTTLS';

	/// it: 'Collega'
	String get connect => 'Collega';

	/// it: 'Annulla'
	String get cancel => 'Annulla';

	/// it: 'Verifica della connessione in corso'
	String get connecting => 'Verifica della connessione in corso';

	/// it: 'Scrivi un indirizzo email completo.'
	String get invalidAddress => 'Scrivi un indirizzo email completo.';

	/// it: 'Scrivi la password.'
	String get emptyPassword => 'Scrivi la password.';

	/// it: 'Scrivi l'host del server.'
	String get invalidHost => 'Scrivi l\'host del server.';

	/// it: 'Scrivi una porta tra 1 e 65535.'
	String get invalidPort => 'Scrivi una porta tra 1 e 65535.';

	/// it: 'Il server ha rifiutato indirizzo o password.'
	String get authRejected => 'Il server ha rifiutato indirizzo o password.';

	/// it: 'Non ho trovato i server di questo indirizzo: inseriscili qui sotto.'
	String get serverNotFound => 'Non ho trovato i server di questo indirizzo: inseriscili qui sotto.';

	/// it: 'Server non raggiungibile: controlla la connessione, l'host e la porta.'
	String get unreachable => 'Server non raggiungibile: controlla la connessione, l\'host e la porta.';

	/// it: 'Questo Account è già collegato.'
	String get alreadyConnected => 'Questo Account è già collegato.';

	/// it: 'Per un indirizzo Gmail usa «Collega Gmail».'
	String get useGmail => 'Per un indirizzo Gmail usa «Collega Gmail».';
}

// Path: accounts
class Translations$accounts$it {
	Translations$accounts$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Account'
	String get section => 'Account';

	/// it: 'Aggiungi Account'
	String get add => 'Aggiungi Account';

	/// it: 'Gmail'
	String get gmail => 'Gmail';

	/// it: 'iCloud'
	String get icloud => 'iCloud';

	/// it: 'IMAP'
	String get imap => 'IMAP';

	/// it: 'Microsoft'
	String get microsoft => 'Microsoft';

	/// it: 'Rimuovi l'Account $address'
	String remove({required Object address}) => 'Rimuovi l\'Account ${address}';

	/// it: 'Rimuovere l'Account $name?'
	String removeTitle({required Object name}) => 'Rimuovere l\'Account ${name}?';

	/// it: 'Le email scaricate su questo dispositivo vengono eliminate; sul server restano come sono.'
	String get removeMessage => 'Le email scaricate su questo dispositivo vengono eliminate; sul server restano come sono.';

	/// it: 'Le modifiche non ancora inviate al server vanno perse.'
	String get removeNote => 'Le modifiche non ancora inviate al server vanno perse.';

	/// it: 'Postino revoca anche il suo accesso a Gmail su Google: gli altri dispositivi collegati con questo Account dovranno ricollegarlo.'
	String get removeGmailNote => 'Postino revoca anche il suo accesso a Gmail su Google: gli altri dispositivi collegati con questo Account dovranno ricollegarlo.';

	/// it: 'Rimuovi'
	String get removeConfirm => 'Rimuovi';

	/// it: 'Annulla'
	String get removeCancel => 'Annulla';
}

// Path: etichetteAutomatiche.model
class Translations$etichetteAutomatiche$model$it {
	Translations$etichetteAutomatiche$model$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Preparazione del modello'
	String get preparing => 'Preparazione del modello';

	/// it: 'In attesa del Wi-Fi'
	String get waitingTitle => 'In attesa del Wi-Fi';

	/// it: 'Il modello ($size) si scarica quando sei in Wi-Fi.'
	String waitingBody({required Object size}) => 'Il modello (${size}) si scarica quando sei in Wi-Fi.';

	/// it: 'Scarica ora'
	String get downloadNow => 'Scarica ora';

	/// it: 'Download del modello'
	String get downloading => 'Download del modello';

	/// it: '$received di $total · $percent%'
	String progress({required Object received, required Object total, required Object percent}) => '${received} di ${total} · ${percent}%';

	/// it: 'Download del modello non riuscito'
	String get failedTitle => 'Download del modello non riuscito';

	/// it: 'Connessione interrotta.'
	String get failedOffline => 'Connessione interrotta.';

	/// it: 'Errore imprevisto.'
	String get failedOther => 'Errore imprevisto.';

	/// it: 'Riprova'
	String get retry => 'Riprova';

	/// it: 'Modello pronto'
	String get ready => 'Modello pronto';

	/// it: 'Le email nuove ricevono le Etichette automatiche.'
	String get readyBody => 'Le email nuove ricevono le Etichette automatiche.';

	/// it: 'Etichette automatiche pronte'
	String get readySnackbar => 'Etichette automatiche pronte';

	/// it: 'Ok'
	String get dismiss => 'Ok';

	/// it: 'Scaricare $size su rete cellulare?'
	String confirmTitle({required Object size}) => 'Scaricare ${size} su rete cellulare?';

	/// it: 'Aspetta il Wi-Fi'
	String get confirmWait => 'Aspetta il Wi-Fi';
}

// Path: conflitti.values
class Translations$conflitti$values$it {
	Translations$conflitti$values$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'letto'
	String get read => 'letto';

	/// it: 'da leggere'
	String get unread => 'da leggere';

	/// it: 'con Stella'
	String get starred => 'con Stella';

	/// it: 'senza Stella'
	String get unstarred => 'senza Stella';

	/// it: 'in posta in arrivo'
	String get inbox => 'in posta in arrivo';

	/// it: 'archiviato'
	String get archive => 'archiviato';

	/// it: 'nel Cestino'
	String get trash => 'nel Cestino';

	/// it: 'con l'etichetta $name'
	String labeled({required Object name}) => 'con l\'etichetta ${name}';

	/// it: 'senza l'etichetta $name'
	String unlabeled({required Object name}) => 'senza l\'etichetta ${name}';
}

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Postino',
			'postaUnificata' => 'Posta unificata',
			'postaInArrivo' => 'Posta in arrivo',
			'account' => 'Account',
			'accountCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, one: '${n} account', other: '${n} account', ), 
			'sidebar.close' => 'Chiudi la barra laterale',
			'sidebar.open' => 'Apri la barra laterale',
			'listWidth.label' => 'Larghezza lista',
			'listWidth.value' => ({required Object px}) => '${px} pixel',
			'etichette' => 'Etichette',
			'onboarding.body' => 'Tutte le tue caselle in un posto solo.',
			'onboarding.connectGmail' => 'Collega Gmail',
			'onboarding.connectIcloud' => 'Collega iCloud',
			'onboarding.connectImap' => 'Altro IMAP',
			'daRicollegare.title' => ({required Object name}) => '${name} è da ricollegare',
			'daRicollegare.message' => 'Google non accetta più l\'accesso. La posta resta leggibile ma non si aggiorna finché non accedi.',
			'daRicollegare.signIn' => 'Accedi',
			'daRicollegare.status' => 'Da ricollegare',
			'daRicollegare.passwordMessage' => 'Il server non accetta più la password. La posta resta leggibile ma non si aggiorna finché non accedi.',
			'connect.title' => 'Collegamento non riuscito',
			'connect.missingSetting' => ({required Object setting}) => 'Manca ${setting}: avvia Postino con --dart-define=${setting}=… (vedi README).',
			'connect.offline' => 'Nessuna connessione: riprova quando sei online.',
			'connect.missingPermission' => 'Serve l\'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.',
			'connect.wrongAccount' => ({required Object address}) => 'Hai scelto un altro account Google: per ricollegare ${address} scegli quell\'account.',
			'connect.failed' => 'Qualcosa è andato storto: riprova.',
			'connect.alreadyConnected' => 'Questo indirizzo è già collegato come un altro Account.',
			'offline.title' => 'Sei offline',
			'offline.message' => 'La posta si aggiornerà al ritorno della rete.',
			'list.loading' => 'Caricamento dei messaggi',
			'list.emptyTitle' => 'Niente di nuovo',
			'list.emptyBody' => 'I messaggi compaiono qui appena arrivano.',
			'list.yesterday' => 'Ieri',
			'list.unread' => 'Non letto',
			'list.starred' => 'con Stella',
			'list.account' => ({required Object name}) => 'account ${name}',
			'list.messages' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, one: '${n} messaggio', other: '${n} messaggi', ), 
			'conversazione.selectTitle' => 'Seleziona una Conversazione',
			'conversazione.selectBody' => 'Scegli una Conversazione dalla lista per leggerla qui.',
			'conversazione.to' => ({required Object recipients}) => 'a ${recipients}',
			'conversazione.loading' => 'Caricamento…',
			'conversazione.offline' => 'Corpo non disponibile offline',
			'conversazione.failed' => 'Corpo non disponibile',
			'conversazione.retry' => 'Riprova',
			'conversazione.imagesBlocked' => 'Immagini remote bloccate',
			'conversazione.showImages' => 'Mostra immagini',
			'conversazione.alwaysFromSender' => 'Sempre da questo mittente',
			'conversazione.me' => 'me',
			'conversazione.from' => 'Da',
			'conversazione.toLabel' => 'A',
			'conversazione.date' => 'Data',
			'conversazione.receivedOn' => 'Ricevuto su',
			'conversazione.imagesBlockedBody' => 'Caricarle direbbe al mittente che hai aperto il messaggio.',
			'conversazione.toCc' => ({required Object recipients, required Object cc}) => 'a ${recipients}, cc ${cc}',
			'conversazione.cc' => 'Cc',
			'conversazione.showQuoted' => 'Mostra testo citato',
			'conversazione.blockedImage' => 'Immagine bloccata',
			'conversazione.announcement' => ({required num n, required Object subject}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, one: '${subject}, ${n} messaggio', other: '${subject}, ${n} messaggi', ), 
			'conversazione.important' => 'Importante',
			'conversazione.attachmentOpen' => 'Apri',
			'conversazione.attachmentDownloading' => ({required Object percent}) => 'Scaricamento… ${percent}%',
			'conversazione.attachmentCancel' => 'Annulla scaricamento',
			'conversazione.attachmentOffline' => 'Offline: allegato non ancora scaricato',
			'conversazione.attachmentFailed' => 'Scaricamento non riuscito',
			'conversazione.attachmentMore' => 'Altre azioni',
			'conversazione.attachmentSave' => 'Salva…',
			'conversazione.attachmentSaveFailed' => 'Salvataggio non riuscito',
			'conversazione.attachmentExecutable' => 'Eseguibile: non si apre da Postino. Salvalo solo se ti fidi del mittente',
			'conversazione.attachmentUntitled' => 'Allegato senza nome',
			'conversazione.reply' => 'Rispondi',
			'conversazione.replyAll' => 'Rispondi a tutti',
			'conversazione.forward' => 'Inoltra',
			'conversazione.forwardUnavailable' => 'Impossibile inoltrare: messaggio non scaricato',
			'conversazione.messageActions' => 'Azioni del messaggio',
			'conversazione.viewOriginal' => 'Vedi originale',
			'conversazione.originalTitle' => 'Messaggio originale',
			'conversazione.linkWarningTitle' => 'Questo link porta a un altro sito',
			'conversazione.linkWarningBody' => ({required Object domain}) => 'Il testo del link mostra un indirizzo diverso da quello vero. Se lo apri, vai su ${domain}.',
			'conversazione.linkUnverifiedBody' => ({required Object domain}) => 'Non si può verificare dove porta questo link. Se lo apri, vai su ${domain}.',
			'conversazione.linkWarningPunycode' => 'Il nome del sito usa caratteri speciali (punycode): potrebbe imitarne un altro.',
			'conversazione.linkOpen' => 'Apri il link',
			'conversazione.linkCancel' => 'Non aprire',
			'composizione.title' => 'Nuovo messaggio',
			'composizione.write' => 'Scrivi',
			'composizione.from' => 'Da',
			'composizione.to' => 'A',
			'composizione.cc' => 'Cc',
			'composizione.bcc' => 'Ccn',
			'composizione.subject' => 'Oggetto',
			'composizione.body' => 'Scrivi il messaggio',
			'composizione.close' => 'Chiudi',
			'composizione.bold' => 'Grassetto',
			'composizione.italic' => 'Corsivo',
			'composizione.underline' => 'Sottolineato',
			'composizione.strikethrough' => 'Barrato',
			'composizione.link' => 'Link',
			'composizione.bulletList' => 'Elenco puntato',
			'composizione.numberedList' => 'Elenco numerato',
			'composizione.linkUrl' => 'Indirizzo del link',
			'composizione.insert' => 'Inserisci',
			'composizione.cancel' => 'Annulla',
			'composizione.editor' => 'Corpo del messaggio',
			'composizione.draftNotFound' => 'Bozza non trovata',
			'composizione.draftWithAttachments' => 'Questa Bozza ha allegati: modificala dal client che l\'ha creata',
			'composizione.draftReply' => 'Questa Bozza è una risposta: modificala dal client che l\'ha creata',
			'composizione.send' => 'Invia',
			'composizione.queued' => 'In attesa d\'invio',
			'composizione.undo' => 'Annulla',
			'composizione.tooLarge' => ({required Object mb}) => 'Il messaggio supera il limite di ${mb} MB di Gmail',
			'composizione.sendFailed' => 'Invio non riuscito: riprova',
			'composizione.offlineAttachments' => 'Sei offline: gli allegati dell\'inoltro non sono ancora scaricati, riprova in rete',
			'composizione.noRecipient' => 'Aggiungi almeno un destinatario',
			'composizione.forwardedAttachments' => 'Allegati',
			'bozze.title' => 'Bozze',
			'bozze.emptyTitle' => 'Nessuna bozza',
			'bozze.emptyBody' => 'Le bozze che scrivi restano qui finché non le invii.',
			'inviati.title' => 'Inviati',
			'inviati.waiting' => 'In attesa d\'invio',
			'inviati.offline' => 'In uscita, in attesa di rete',
			'inviati.failed' => 'Invio non riuscito',
			'inviati.emptyTitle' => 'Nessun messaggio inviato',
			'inviati.emptyBody' => 'I messaggi che invii compaiono qui.',
			'impostazioni.title' => 'Impostazioni',
			'impostazioni.deviceSection' => 'Dispositivo',
			'impostazioni.device' => 'Impostazioni del dispositivo',
			'impostazioni.launchAtLogin' => 'Avvio al login',
			'impostazioni.launchAtLoginBody' => 'Postino si apre quando accedi al computer e resta nella tray, così la posta continua ad arrivare.',
			'impostazioni.launchAtLoginFailed' => 'Il sistema non ha accettato la modifica. Riprova, o controlla gli elementi di login nelle impostazioni di sistema.',
			'impostazioni.checkForUpdates' => 'Cerca aggiornamenti',
			'impostazioni.checkForUpdatesBody' => 'Cerca subito una nuova versione di Postino.',
			'impostazioni.syncSection' => 'Sincronizzazione',
			'impostazioni.syncTitle' => 'Sincronizza su…',
			'impostazioni.syncNone' => 'Nessuno',
			'impostazioni.syncBody' => 'Le Impostazioni di Postino (per esempio le Etichette automatiche) vengono salvate in un file nascosto nel Google Drive dell\'Account scelto, senza credenziali. Postino chiede a Google l\'accesso a quello spazio nascosto di Drive, non ai tuoi file.',
			'impostazioni.syncChooserTitle' => 'Sincronizza le Impostazioni su',
			'impostazioni.syncCancel' => 'Annulla',
			'impostazioni.syncBusy' => 'Accesso a Drive in corso…',
			'impostazioni.syncDenied' => 'Google non ha concesso l\'accesso allo spazio nascosto di Drive. La sincronizzazione resta com\'era.',
			'impostazioni.syncWrongAccount' => ({required Object address}) => 'Hai scelto un altro account Google. Scegli ${address}.',
			'impostazioni.syncOffline' => 'Sei offline. Riprova quando torna la rete.',
			'impostazioni.syncFailed' => 'Non è stato possibile collegare Drive. Riprova.',
			'segnalazione.action' => 'Segnala un problema',
			'segnalazione.subject' => 'Problema in Postino',
			'segnalazione.intro' => 'Descrivi qui cosa è andato storto. Sotto trovi il log degli errori di Postino: senza password né token, rileggilo prima di inviare.',
			'segnalazione.crashTitle' => 'Postino si è chiuso in modo imprevisto',
			'segnalazione.crashBody' => 'Vuoi segnalare il problema? Si apre una bozza con il log degli errori: la rileggi e decidi tu se inviarla.',
			'segnalazione.crashConfirm' => 'Segnala',
			'segnalazione.crashDismiss' => 'Non ora',
			'tray.open' => 'Apri Postino',
			'tray.quit' => 'Esci',
			'selettoreEtichette.button' => 'Etichette',
			'selettoreEtichette.menuItem' => 'Etichette…',
			'selettoreEtichette.close' => 'Chiudi le Etichette',
			'selettoreEtichette.search' => 'Cerca o crea un\'Etichetta',
			'selettoreEtichette.nestHelp' => 'Usa «/» per annidarla, es. Progetti/Postino.',
			'selettoreEtichette.create' => ({required Object name}) => 'Crea «${name}»',
			'selettoreEtichette.selected' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, zero: 'Etichette, nessuna selezionata', one: 'Etichette, ${n} selezionata', other: 'Etichette, ${n} selezionate', ), 
			'selettoreEtichette.empty' => 'Nessuna Etichetta',
			'selettoreEtichette.removed' => ({required Object name}) => 'Etichetta «${name}» tolta',
			'selettoreEtichette.undo' => 'Annulla',
			'selettoreEtichette.remove' => ({required Object name}) => 'Togli Etichetta ${name}',
			'selettoreEtichette.errorEmpty' => 'Scrivi un nome per l\'Etichetta.',
			'selettoreEtichette.errorEmptyLevel' => 'Ogni livello ha bisogno di un nome: niente «/» all\'inizio, alla fine o doppie.',
			'selettoreEtichette.errorDuplicate' => 'Esiste già un\'Etichetta con questo nome.',
			'etichetteAutomatiche.title' => 'Etichette automatiche',
			'etichetteAutomatiche.page' => ({required Object account}) => 'Impostazioni · ${account}',
			'etichetteAutomatiche.intro' => 'Un modello che gira sul tuo dispositivo assegna le Etichette alle email in arrivo.\nVale solo per le email nuove arrivate dopo l\'attivazione.\nOgni email riceve al massimo un\'Etichetta, e quelle che ne hanno già una vengono saltate.\nL\'Etichetta viene scritta su Gmail.',
			'etichetteAutomatiche.labels' => 'Etichette',
			'etichetteAutomatiche.empty' => 'Nessuna Etichetta: creane una per iniziare.',
			'etichetteAutomatiche.automatic' => 'Automatica',
			'etichetteAutomatiche.description' => 'Descrizione (facoltativa)',
			'etichetteAutomatiche.descriptionHelp' => 'Descrivi che email ci vanno, es. fatture e ricevute dei fornitori',
			'etichetteAutomatiche.descriptionSaved' => 'Descrizione salvata',
			'etichetteAutomatiche.create' => 'Crea Etichetta',
			'etichetteAutomatiche.createTitle' => 'Crea Etichetta',
			'etichetteAutomatiche.createName' => 'Nome dell\'Etichetta',
			'etichetteAutomatiche.createHelp' => 'Usa «/» per annidarla, es. Progetti/Postino.',
			'etichetteAutomatiche.createAction' => 'Crea',
			'etichetteAutomatiche.createCancel' => 'Annulla',
			'etichetteAutomatiche.createFailed' => 'Non è stato possibile creare l\'Etichetta. Controlla la connessione e riprova.',
			'etichetteAutomatiche.errorEmpty' => 'Scrivi un nome per l\'Etichetta.',
			'etichetteAutomatiche.errorEmptyLevel' => 'Ogni livello ha bisogno di un nome: niente «/» all\'inizio, alla fine o doppie.',
			'etichetteAutomatiche.errorDuplicate' => 'Esiste già un\'Etichetta con questo nome.',
			'etichetteAutomatiche.model.preparing' => 'Preparazione del modello',
			'etichetteAutomatiche.model.waitingTitle' => 'In attesa del Wi-Fi',
			'etichetteAutomatiche.model.waitingBody' => ({required Object size}) => 'Il modello (${size}) si scarica quando sei in Wi-Fi.',
			'etichetteAutomatiche.model.downloadNow' => 'Scarica ora',
			'etichetteAutomatiche.model.downloading' => 'Download del modello',
			'etichetteAutomatiche.model.progress' => ({required Object received, required Object total, required Object percent}) => '${received} di ${total} · ${percent}%',
			'etichetteAutomatiche.model.failedTitle' => 'Download del modello non riuscito',
			'etichetteAutomatiche.model.failedOffline' => 'Connessione interrotta.',
			'etichetteAutomatiche.model.failedOther' => 'Errore imprevisto.',
			'etichetteAutomatiche.model.retry' => 'Riprova',
			'etichetteAutomatiche.model.ready' => 'Modello pronto',
			'etichetteAutomatiche.model.readyBody' => 'Le email nuove ricevono le Etichette automatiche.',
			'etichetteAutomatiche.model.readySnackbar' => 'Etichette automatiche pronte',
			'etichetteAutomatiche.model.dismiss' => 'Ok',
			'etichetteAutomatiche.model.confirmTitle' => ({required Object size}) => 'Scaricare ${size} su rete cellulare?',
			'etichetteAutomatiche.model.confirmWait' => 'Aspetta il Wi-Fi',
			'notifiche.channel' => 'Posta nuova',
			'notifiche.open' => 'Apri',
			'notifiche.permissionTitle' => 'Notifiche della posta nuova',
			'notifiche.permissionBody' => 'Postino ti avvisa quando arriva un messaggio, con mittente, oggetto e anteprima. Il sistema ti chiederà il permesso.',
			'notifiche.permissionAllow' => 'Continua',
			'notifiche.permissionLater' => 'Non ora',
			'conflitti.bannerTitle' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, one: '${n} conflitto', other: '${n} conflitti', ), 
			'conflitti.bannerMessage' => 'Hai cambiato dei messaggi offline e nel frattempo sono cambiati anche altrove.',
			'conflitti.open' => 'Vedi',
			'conflitti.title' => 'Conflitti',
			'conflitti.emptyTitle' => 'Nessun conflitto',
			'conflitti.emptyBody' => 'Quando un messaggio cambia in due posti, lo trovi qui.',
			'conflitti.keepMine' => 'La tua',
			'conflitti.keepProvider' => 'Del Provider',
			'conflitti.mine' => ({required Object value}) => 'La tua: ${value}',
			'conflitti.provider' => ({required Object value}) => 'Provider: ${value}',
			'conflitti.sign' => 'In conflitto',
			'conflitti.signFor' => ({required Object sender, required Object time}) => 'In conflitto: ${sender}, ${time}',
			'conflitti.signMessage' => 'Questo messaggio è cambiato anche altrove. Qui vedi la tua versione.',
			'conflitti.account' => ({required Object name}) => 'account ${name}',
			'conflitti.noSubject' => '(senza oggetto)',
			'conflitti.draft' => 'Bozza',
			'conflitti.draftMine' => ({required Object subject, required Object body}) => 'La tua versione: oggetto ${subject}, testo ${body}',
			'conflitti.draftProvider' => ({required Object subject, required Object body}) => 'Versione del Provider: oggetto ${subject}, testo ${body}',
			'conflitti.values.read' => 'letto',
			'conflitti.values.unread' => 'da leggere',
			'conflitti.values.starred' => 'con Stella',
			'conflitti.values.unstarred' => 'senza Stella',
			'conflitti.values.inbox' => 'in posta in arrivo',
			'conflitti.values.archive' => 'archiviato',
			'conflitti.values.trash' => 'nel Cestino',
			'conflitti.values.labeled' => ({required Object name}) => 'con l\'etichetta ${name}',
			'conflitti.values.unlabeled' => ({required Object name}) => 'senza l\'etichetta ${name}',
			'azioni.archive' => 'Archivia',
			'azioni.delete' => 'Elimina',
			'azioni.star' => 'Aggiungi stella',
			'azioni.unstar' => 'Togli stella',
			'azioni.markRead' => 'Segna come letto',
			'azioni.markUnread' => 'Segna come non letto',
			'azioni.archived' => 'Conversazione archiviata',
			'azioni.deleted' => 'Conversazione spostata nel Cestino',
			'azioni.labelApplied' => ({required Object name}) => 'Etichetta «${name}» applicata',
			'azioni.undo' => 'Annulla',
			'azioni.more' => 'Altre azioni',
			'azioni.applyLabel' => 'Applica Etichetta',
			'scorrimento.title' => 'Azioni per scorrimento',
			'scorrimento.intro' => 'Scorrendo una riga della lista si esegue un\'Azione. La scelta vale per tutti gli Account.',
			'scorrimento.left' => 'Scorrimento a sinistra',
			'scorrimento.right' => 'Scorrimento a destra',
			'scorrimento.markRead' => 'Segna come letto/non letto',
			'scorrimento.star' => 'Stella',
			'passwordForm.icloudTitle' => 'Collega iCloud',
			'passwordForm.imapTitle' => 'Collega un Account IMAP',
			'passwordForm.reconnectTitle' => 'Ricollega l\'Account',
			'passwordForm.address' => 'Indirizzo email',
			'passwordForm.password' => 'Password',
			'passwordForm.appPassword' => 'Password per app',
			'passwordForm.icloudHelp' => 'iCloud chiede una password per app, non la password del tuo Apple Account.',
			'passwordForm.appleLink' => 'Come creare una password per app',
			'passwordForm.manual' => 'Impostazione manuale dei server',
			'passwordForm.imapServer' => 'Server IMAP (posta in arrivo)',
			'passwordForm.smtpServer' => 'Server SMTP (posta in uscita)',
			'passwordForm.host' => 'Host',
			'passwordForm.port' => 'Porta',
			'passwordForm.ssl' => 'SSL/TLS',
			'passwordForm.starttls' => 'STARTTLS',
			'passwordForm.connect' => 'Collega',
			'passwordForm.cancel' => 'Annulla',
			'passwordForm.connecting' => 'Verifica della connessione in corso',
			'passwordForm.invalidAddress' => 'Scrivi un indirizzo email completo.',
			'passwordForm.emptyPassword' => 'Scrivi la password.',
			'passwordForm.invalidHost' => 'Scrivi l\'host del server.',
			'passwordForm.invalidPort' => 'Scrivi una porta tra 1 e 65535.',
			'passwordForm.authRejected' => 'Il server ha rifiutato indirizzo o password.',
			'passwordForm.serverNotFound' => 'Non ho trovato i server di questo indirizzo: inseriscili qui sotto.',
			'passwordForm.unreachable' => 'Server non raggiungibile: controlla la connessione, l\'host e la porta.',
			'passwordForm.alreadyConnected' => 'Questo Account è già collegato.',
			'passwordForm.useGmail' => 'Per un indirizzo Gmail usa «Collega Gmail».',
			'accounts.section' => 'Account',
			'accounts.add' => 'Aggiungi Account',
			'accounts.gmail' => 'Gmail',
			'accounts.icloud' => 'iCloud',
			'accounts.imap' => 'IMAP',
			'accounts.microsoft' => 'Microsoft',
			'accounts.remove' => ({required Object address}) => 'Rimuovi l\'Account ${address}',
			'accounts.removeTitle' => ({required Object name}) => 'Rimuovere l\'Account ${name}?',
			'accounts.removeMessage' => 'Le email scaricate su questo dispositivo vengono eliminate; sul server restano come sono.',
			'accounts.removeNote' => 'Le modifiche non ancora inviate al server vanno perse.',
			'accounts.removeGmailNote' => 'Postino revoca anche il suo accesso a Gmail su Google: gli altri dispositivi collegati con questo Account dovranno ricollegarlo.',
			'accounts.removeConfirm' => 'Rimuovi',
			'accounts.removeCancel' => 'Annulla',
			_ => null,
		};
	}
}
