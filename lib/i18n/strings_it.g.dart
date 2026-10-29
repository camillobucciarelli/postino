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

	/// it: 'Etichette'
	String get etichette => 'Etichette';

	late final Translations$onboarding$it onboarding = Translations$onboarding$it.internal(_root);
	late final Translations$daRicollegare$it daRicollegare = Translations$daRicollegare$it.internal(_root);
	late final Translations$connect$it connect = Translations$connect$it.internal(_root);
	late final Translations$offline$it offline = Translations$offline$it.internal(_root);
	late final Translations$list$it list = Translations$list$it.internal(_root);
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
			_ => null,
		};
	}
}
