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

	late final Translations$onboarding$it onboarding = Translations$onboarding$it.internal(_root);
	late final Translations$daRicollegare$it daRicollegare = Translations$daRicollegare$it.internal(_root);
	late final Translations$connect$it connect = Translations$connect$it.internal(_root);
}

// Path: onboarding
class Translations$onboarding$it {
	Translations$onboarding$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Benvenuto in Postino'
	String get title => 'Benvenuto in Postino';

	/// it: 'Collega la tua casella Gmail per iniziare.'
	String get body => 'Collega la tua casella Gmail per iniziare.';

	/// it: 'Collega Gmail'
	String get connectGmail => 'Collega Gmail';
}

// Path: daRicollegare
class Translations$daRicollegare$it {
	Translations$daRicollegare$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: '$address è da ricollegare: la sua posta resta leggibile ma non si aggiorna.'
	String banner({required Object address}) => '${address} è da ricollegare: la sua posta resta leggibile ma non si aggiorna.';

	/// it: 'Ricollega'
	String get reconnect => 'Ricollega';
}

// Path: connect
class Translations$connect$it {
	Translations$connect$it.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// it: 'Manca $setting: avvia Postino con --dart-define=$setting=… (vedi README).'
	String missingSetting({required Object setting}) => 'Manca ${setting}: avvia Postino con --dart-define=${setting}=… (vedi README).';

	/// it: 'Nessuna connessione: riprova quando sei online.'
	String get offline => 'Nessuna connessione: riprova quando sei online.';

	/// it: 'Serve l'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.'
	String get missingPermission => 'Serve l\'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.';

	/// it: 'Collegamento non riuscito. Riprova.'
	String get failed => 'Collegamento non riuscito. Riprova.';
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
			'onboarding.title' => 'Benvenuto in Postino',
			'onboarding.body' => 'Collega la tua casella Gmail per iniziare.',
			'onboarding.connectGmail' => 'Collega Gmail',
			'daRicollegare.banner' => ({required Object address}) => '${address} è da ricollegare: la sua posta resta leggibile ma non si aggiorna.',
			'daRicollegare.reconnect' => 'Ricollega',
			'connect.missingSetting' => ({required Object setting}) => 'Manca ${setting}: avvia Postino con --dart-define=${setting}=… (vedi README).',
			'connect.offline' => 'Nessuna connessione: riprova quando sei online.',
			'connect.missingPermission' => 'Serve l\'accesso a Gmail: riprova e lascia spuntato il permesso per leggere e gestire la posta.',
			'connect.failed' => 'Collegamento non riuscito. Riprova.',
			_ => null,
		};
	}
}
