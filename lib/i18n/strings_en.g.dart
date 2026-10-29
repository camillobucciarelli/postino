///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsEn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Postino';
	@override String get postaUnificata => 'All inboxes';
	@override String get postaInArrivo => 'Inbox';
	@override String get account => 'Accounts';
	@override String accountCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} account',
		other: '${n} accounts',
	);
	@override String get etichette => 'Labels';
	@override late final _Translations$onboarding$en onboarding = _Translations$onboarding$en._(_root);
	@override late final _Translations$daRicollegare$en daRicollegare = _Translations$daRicollegare$en._(_root);
	@override late final _Translations$connect$en connect = _Translations$connect$en._(_root);
	@override late final _Translations$offline$en offline = _Translations$offline$en._(_root);
	@override late final _Translations$list$en list = _Translations$list$en._(_root);
}

// Path: onboarding
class _Translations$onboarding$en extends Translations$onboarding$it {
	_Translations$onboarding$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get body => 'All your mailboxes in one place.';
	@override String get connectGmail => 'Connect Gmail';
}

// Path: daRicollegare
class _Translations$daRicollegare$en extends Translations$daRicollegare$it {
	_Translations$daRicollegare$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => '${name} needs signing in again';
	@override String get message => 'Google no longer accepts the sign-in. Mail stays readable but won\'t update until you sign in.';
	@override String get signIn => 'Sign in';
	@override String get status => 'Needs signing in';
}

// Path: connect
class _Translations$connect$en extends Translations$connect$it {
	_Translations$connect$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Couldn\'t connect';
	@override String missingSetting({required Object setting}) => '${setting} is missing: start Postino with --dart-define=${setting}=… (see README).';
	@override String get offline => 'No connection: try again when you are online.';
	@override String get missingPermission => 'Gmail access is required: try again and keep the permission to read and manage your mail ticked.';
	@override String wrongAccount({required Object address}) => 'You picked a different Google account: to reconnect ${address}, pick that account.';
	@override String get failed => 'Something went wrong: try again.';
}

// Path: offline
class _Translations$offline$en extends Translations$offline$it {
	_Translations$offline$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'You\'re offline';
	@override String get message => 'Mail will update when the network is back.';
}

// Path: list
class _Translations$list$en extends Translations$list$it {
	_Translations$list$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Loading messages';
	@override String get emptyTitle => 'Nothing new';
	@override String get emptyBody => 'Messages show up here as they arrive.';
	@override String get yesterday => 'Yesterday';
	@override String get unread => 'Unread';
	@override String get starred => 'starred';
	@override String account({required Object name}) => 'account ${name}';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Postino',
			'postaUnificata' => 'All inboxes',
			'postaInArrivo' => 'Inbox',
			'account' => 'Accounts',
			'accountCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} account', other: '${n} accounts', ), 
			'etichette' => 'Labels',
			'onboarding.body' => 'All your mailboxes in one place.',
			'onboarding.connectGmail' => 'Connect Gmail',
			'daRicollegare.title' => ({required Object name}) => '${name} needs signing in again',
			'daRicollegare.message' => 'Google no longer accepts the sign-in. Mail stays readable but won\'t update until you sign in.',
			'daRicollegare.signIn' => 'Sign in',
			'daRicollegare.status' => 'Needs signing in',
			'connect.title' => 'Couldn\'t connect',
			'connect.missingSetting' => ({required Object setting}) => '${setting} is missing: start Postino with --dart-define=${setting}=… (see README).',
			'connect.offline' => 'No connection: try again when you are online.',
			'connect.missingPermission' => 'Gmail access is required: try again and keep the permission to read and manage your mail ticked.',
			'connect.wrongAccount' => ({required Object address}) => 'You picked a different Google account: to reconnect ${address}, pick that account.',
			'connect.failed' => 'Something went wrong: try again.',
			'offline.title' => 'You\'re offline',
			'offline.message' => 'Mail will update when the network is back.',
			'list.loading' => 'Loading messages',
			'list.emptyTitle' => 'Nothing new',
			'list.emptyBody' => 'Messages show up here as they arrive.',
			'list.yesterday' => 'Yesterday',
			'list.unread' => 'Unread',
			'list.starred' => 'starred',
			'list.account' => ({required Object name}) => 'account ${name}',
			_ => null,
		};
	}
}
