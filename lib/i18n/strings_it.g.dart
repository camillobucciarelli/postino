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
			'daRicollegare.title' => ({required Object name}) => '${name} è da ricollegare',
			'daRicollegare.message' => 'Google non accetta più l\'accesso. La posta resta leggibile ma non si aggiorna finché non accedi.',
			'daRicollegare.signIn' => 'Accedi',
			'daRicollegare.status' => 'Da ricollegare',
			'connect.title' => 'Collegamento non riuscito',
			'connect.missingSetting' => ({required Object setting}) => 'Manca ${setting}: avvia Postino con --dart-define=${setting}=… (vedi README).',
			'connect.offline' => 'Nessuna connessione: riprova quando sei online.',
			'connect.missingPermission' => 'Serve l\'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.',
			'connect.wrongAccount' => ({required Object address}) => 'Hai scelto un altro account Google: per ricollegare ${address} scegli quell\'account.',
			'connect.failed' => 'Qualcosa è andato storto: riprova.',
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
			_ => null,
		};
	}
}
