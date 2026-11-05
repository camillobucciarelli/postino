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
	@override late final _Translations$sidebar$en sidebar = _Translations$sidebar$en._(_root);
	@override late final _Translations$listWidth$en listWidth = _Translations$listWidth$en._(_root);
	@override String get etichette => 'Labels';
	@override late final _Translations$onboarding$en onboarding = _Translations$onboarding$en._(_root);
	@override late final _Translations$daRicollegare$en daRicollegare = _Translations$daRicollegare$en._(_root);
	@override late final _Translations$connect$en connect = _Translations$connect$en._(_root);
	@override late final _Translations$offline$en offline = _Translations$offline$en._(_root);
	@override late final _Translations$list$en list = _Translations$list$en._(_root);
	@override late final _Translations$conversazione$en conversazione = _Translations$conversazione$en._(_root);
	@override late final _Translations$composizione$en composizione = _Translations$composizione$en._(_root);
	@override late final _Translations$bozze$en bozze = _Translations$bozze$en._(_root);
	@override late final _Translations$inviati$en inviati = _Translations$inviati$en._(_root);
	@override late final _Translations$impostazioni$en impostazioni = _Translations$impostazioni$en._(_root);
	@override late final _Translations$tray$en tray = _Translations$tray$en._(_root);
	@override late final _Translations$selettoreEtichette$en selettoreEtichette = _Translations$selettoreEtichette$en._(_root);
	@override late final _Translations$etichetteAutomatiche$en etichetteAutomatiche = _Translations$etichetteAutomatiche$en._(_root);
	@override late final _Translations$notifiche$en notifiche = _Translations$notifiche$en._(_root);
}

// Path: sidebar
class _Translations$sidebar$en extends Translations$sidebar$it {
	_Translations$sidebar$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get close => 'Close the sidebar';
	@override String get open => 'Open the sidebar';
}

// Path: listWidth
class _Translations$listWidth$en extends Translations$listWidth$it {
	_Translations$listWidth$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get label => 'List width';
	@override String value({required Object px}) => '${px} pixels';
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
	@override String messages({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} message',
		other: '${n} messages',
	);
}

// Path: conversazione
class _Translations$conversazione$en extends Translations$conversazione$it {
	_Translations$conversazione$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get selectTitle => 'Select a conversation';
	@override String get selectBody => 'Pick a conversation from the list to read it here.';
	@override String to({required Object recipients}) => 'to ${recipients}';
	@override String get loading => 'Loading…';
	@override String get offline => 'Body not available offline';
	@override String get failed => 'Body not available';
	@override String get retry => 'Retry';
	@override String get imagesBlocked => 'Remote images blocked';
	@override String get showImages => 'Show images';
	@override String get alwaysFromSender => 'Always from this sender';
	@override String get me => 'me';
	@override String get from => 'From';
	@override String get toLabel => 'To';
	@override String get date => 'Date';
	@override String get receivedOn => 'Received on';
	@override String get imagesBlockedBody => 'Loading them would tell the sender you opened the message.';
	@override String toCc({required Object recipients, required Object cc}) => 'to ${recipients}, cc ${cc}';
	@override String get cc => 'Cc';
	@override String get showQuoted => 'Show quoted text';
	@override String get blockedImage => 'Blocked image';
	@override String announcement({required num n, required Object subject}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${subject}, ${n} message',
		other: '${subject}, ${n} messages',
	);
	@override String get important => 'Important';
	@override String get attachmentOpen => 'Open';
	@override String attachmentDownloading({required Object percent}) => 'Downloading… ${percent}%';
	@override String get attachmentCancel => 'Cancel download';
	@override String get attachmentOffline => 'Offline: attachment not downloaded yet';
	@override String get attachmentFailed => 'Download failed';
	@override String get attachmentMore => 'More actions';
	@override String get attachmentSave => 'Save…';
	@override String get attachmentSaveFailed => 'Save failed';
	@override String get attachmentExecutable => 'Executable: Postino won\'t open it. Save it only if you trust the sender';
	@override String get attachmentUntitled => 'Untitled attachment';
	@override String get reply => 'Reply';
	@override String get replyAll => 'Reply all';
	@override String get forward => 'Forward';
	@override String get forwardUnavailable => 'Cannot forward: message not downloaded';
	@override String get messageActions => 'Message actions';
	@override String get viewOriginal => 'View original';
	@override String get originalTitle => 'Original message';
	@override String get linkWarningTitle => 'This link goes to a different site';
	@override String linkWarningBody({required Object domain}) => 'The link\'s text shows an address other than the real one. If you open it, you go to ${domain}.';
	@override String linkUnverifiedBody({required Object domain}) => 'Where this link goes cannot be verified. If you open it, you go to ${domain}.';
	@override String get linkWarningPunycode => 'The site\'s name uses special characters (punycode): it may imitate another one.';
	@override String get linkOpen => 'Open the link';
	@override String get linkCancel => 'Don\'t open';
}

// Path: composizione
class _Translations$composizione$en extends Translations$composizione$it {
	_Translations$composizione$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'New message';
	@override String get write => 'Compose';
	@override String get from => 'From';
	@override String get to => 'To';
	@override String get cc => 'Cc';
	@override String get bcc => 'Bcc';
	@override String get subject => 'Subject';
	@override String get body => 'Write your message';
	@override String get close => 'Close';
	@override String get bold => 'Bold';
	@override String get italic => 'Italic';
	@override String get underline => 'Underline';
	@override String get strikethrough => 'Strikethrough';
	@override String get link => 'Link';
	@override String get bulletList => 'Bulleted list';
	@override String get numberedList => 'Numbered list';
	@override String get linkUrl => 'Link address';
	@override String get insert => 'Insert';
	@override String get cancel => 'Cancel';
	@override String get editor => 'Message body';
	@override String get draftNotFound => 'Draft not found';
	@override String get draftWithAttachments => 'This draft has attachments: edit it from the client that created it';
	@override String get draftReply => 'This Draft is a reply: edit it from the client that created it';
	@override String get send => 'Send';
	@override String get queued => 'Waiting to send';
	@override String get undo => 'Undo';
	@override String tooLarge({required Object mb}) => 'The message exceeds Gmail\'s ${mb} MB limit';
	@override String get sendFailed => 'Sending failed: try again';
	@override String get offlineAttachments => 'You are offline: the forwarded attachments are not downloaded yet, try again online';
	@override String get noRecipient => 'Add at least one recipient';
	@override String get forwardedAttachments => 'Attachments';
}

// Path: bozze
class _Translations$bozze$en extends Translations$bozze$it {
	_Translations$bozze$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Drafts';
	@override String get emptyTitle => 'No drafts';
	@override String get emptyBody => 'Drafts you write stay here until you send them.';
}

// Path: inviati
class _Translations$inviati$en extends Translations$inviati$it {
	_Translations$inviati$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sent';
	@override String get waiting => 'Waiting to send';
	@override String get offline => 'Outgoing, waiting for network';
	@override String get failed => 'Sending failed';
	@override String get emptyTitle => 'No sent messages';
	@override String get emptyBody => 'Messages you send show up here.';
}

// Path: impostazioni
class _Translations$impostazioni$en extends Translations$impostazioni$it {
	_Translations$impostazioni$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings';
	@override String get deviceSection => 'Device';
	@override String get device => 'Device settings';
	@override String get launchAtLogin => 'Launch at login';
	@override String get launchAtLoginBody => 'Postino opens when you log in and stays in the tray, so mail keeps arriving.';
	@override String get launchAtLoginFailed => 'The system did not accept the change. Try again, or check the login items in the system settings.';
	@override String get syncSection => 'Sync';
	@override String get syncTitle => 'Sync to…';
	@override String get syncNone => 'None';
	@override String get syncBody => 'Postino\'s settings (for example the automatic labels) are saved in a hidden file in the Google Drive of the Account you choose, without credentials. Postino asks Google for access to that hidden Drive space, not to your files.';
	@override String get syncChooserTitle => 'Sync settings to';
	@override String get syncCancel => 'Cancel';
	@override String get syncBusy => 'Connecting to Drive…';
	@override String get syncDenied => 'Google did not grant access to the hidden Drive space. Syncing stays as it was.';
	@override String syncWrongAccount({required Object address}) => 'You picked another Google account. Pick ${address}.';
	@override String get syncOffline => 'You are offline. Try again when the network is back.';
	@override String get syncFailed => 'Could not connect Drive. Try again.';
}

// Path: tray
class _Translations$tray$en extends Translations$tray$it {
	_Translations$tray$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get open => 'Open Postino';
	@override String get quit => 'Quit';
}

// Path: selettoreEtichette
class _Translations$selettoreEtichette$en extends Translations$selettoreEtichette$it {
	_Translations$selettoreEtichette$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get button => 'Labels';
	@override String get menuItem => 'Labels…';
	@override String get close => 'Close labels';
	@override String get search => 'Search or create a label';
	@override String get nestHelp => 'Use “/” to nest it, e.g. Projects/Postino.';
	@override String create({required Object name}) => 'Create “${name}”';
	@override String selected({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		zero: 'Labels, none selected',
		one: 'Labels, ${n} selected',
		other: 'Labels, ${n} selected',
	);
	@override String get empty => 'No labels';
	@override String removed({required Object name}) => 'Label “${name}” removed';
	@override String get undo => 'Undo';
	@override String remove({required Object name}) => 'Remove label ${name}';
	@override String get errorEmpty => 'Type a name for the label.';
	@override String get errorEmptyLevel => 'Every level needs a name: no “/” at the start, at the end or doubled.';
	@override String get errorDuplicate => 'A label with this name already exists.';
}

// Path: etichetteAutomatiche
class _Translations$etichetteAutomatiche$en extends Translations$etichetteAutomatiche$it {
	_Translations$etichetteAutomatiche$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Automatic labels';
	@override String page({required Object account}) => 'Settings · ${account}';
	@override String get intro => 'A model running on your device assigns labels to incoming email.\nIt only applies to new email that arrives after you turn it on.\nEach email gets at most one label, and email that already has one is skipped.\nThe label is written to Gmail.';
	@override String get labels => 'Labels';
	@override String get empty => 'No labels: create one to start.';
	@override String get automatic => 'Automatic';
	@override String get description => 'Description (optional)';
	@override String get descriptionHelp => 'Describe which email goes here, e.g. invoices and receipts from suppliers';
	@override String get descriptionSaved => 'Description saved';
	@override String get create => 'Create label';
	@override String get createTitle => 'Create label';
	@override String get createName => 'Label name';
	@override String get createHelp => 'Use “/” to nest it, e.g. Projects/Postino.';
	@override String get createAction => 'Create';
	@override String get createCancel => 'Cancel';
	@override String get createFailed => 'The label could not be created. Check your connection and try again.';
	@override String get errorEmpty => 'Type a name for the label.';
	@override String get errorEmptyLevel => 'Every level needs a name: no “/” at the start, at the end or doubled.';
	@override String get errorDuplicate => 'A label with this name already exists.';
	@override late final _Translations$etichetteAutomatiche$model$en model = _Translations$etichetteAutomatiche$model$en._(_root);
}

// Path: notifiche
class _Translations$notifiche$en extends Translations$notifiche$it {
	_Translations$notifiche$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get channel => 'New mail';
	@override String get open => 'Open';
	@override String get permissionTitle => 'New mail notifications';
	@override String get permissionBody => 'Postino lets you know when a message arrives, with its sender, subject and preview. The system will ask for your permission.';
	@override String get permissionAllow => 'Continue';
	@override String get permissionLater => 'Not now';
}

// Path: etichetteAutomatiche.model
class _Translations$etichetteAutomatiche$model$en extends Translations$etichetteAutomatiche$model$it {
	_Translations$etichetteAutomatiche$model$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get preparing => 'Preparing the model';
	@override String get waitingTitle => 'Waiting for Wi-Fi';
	@override String waitingBody({required Object size}) => 'The model (${size}) downloads when you are on Wi-Fi.';
	@override String get downloadNow => 'Download now';
	@override String get downloading => 'Downloading the model';
	@override String progress({required Object received, required Object total, required Object percent}) => '${received} of ${total} · ${percent}%';
	@override String get failedTitle => 'Model download failed';
	@override String get failedOffline => 'Connection lost.';
	@override String get failedOther => 'Unexpected error.';
	@override String get retry => 'Retry';
	@override String get ready => 'Model ready';
	@override String get readyBody => 'New email gets automatic labels.';
	@override String get readySnackbar => 'Automatic labels ready';
	@override String get dismiss => 'OK';
	@override String confirmTitle({required Object size}) => 'Download ${size} over cellular?';
	@override String get confirmWait => 'Wait for Wi-Fi';
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
			'sidebar.close' => 'Close the sidebar',
			'sidebar.open' => 'Open the sidebar',
			'listWidth.label' => 'List width',
			'listWidth.value' => ({required Object px}) => '${px} pixels',
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
			'list.messages' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} message', other: '${n} messages', ), 
			'conversazione.selectTitle' => 'Select a conversation',
			'conversazione.selectBody' => 'Pick a conversation from the list to read it here.',
			'conversazione.to' => ({required Object recipients}) => 'to ${recipients}',
			'conversazione.loading' => 'Loading…',
			'conversazione.offline' => 'Body not available offline',
			'conversazione.failed' => 'Body not available',
			'conversazione.retry' => 'Retry',
			'conversazione.imagesBlocked' => 'Remote images blocked',
			'conversazione.showImages' => 'Show images',
			'conversazione.alwaysFromSender' => 'Always from this sender',
			'conversazione.me' => 'me',
			'conversazione.from' => 'From',
			'conversazione.toLabel' => 'To',
			'conversazione.date' => 'Date',
			'conversazione.receivedOn' => 'Received on',
			'conversazione.imagesBlockedBody' => 'Loading them would tell the sender you opened the message.',
			'conversazione.toCc' => ({required Object recipients, required Object cc}) => 'to ${recipients}, cc ${cc}',
			'conversazione.cc' => 'Cc',
			'conversazione.showQuoted' => 'Show quoted text',
			'conversazione.blockedImage' => 'Blocked image',
			'conversazione.announcement' => ({required num n, required Object subject}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${subject}, ${n} message', other: '${subject}, ${n} messages', ), 
			'conversazione.important' => 'Important',
			'conversazione.attachmentOpen' => 'Open',
			'conversazione.attachmentDownloading' => ({required Object percent}) => 'Downloading… ${percent}%',
			'conversazione.attachmentCancel' => 'Cancel download',
			'conversazione.attachmentOffline' => 'Offline: attachment not downloaded yet',
			'conversazione.attachmentFailed' => 'Download failed',
			'conversazione.attachmentMore' => 'More actions',
			'conversazione.attachmentSave' => 'Save…',
			'conversazione.attachmentSaveFailed' => 'Save failed',
			'conversazione.attachmentExecutable' => 'Executable: Postino won\'t open it. Save it only if you trust the sender',
			'conversazione.attachmentUntitled' => 'Untitled attachment',
			'conversazione.reply' => 'Reply',
			'conversazione.replyAll' => 'Reply all',
			'conversazione.forward' => 'Forward',
			'conversazione.forwardUnavailable' => 'Cannot forward: message not downloaded',
			'conversazione.messageActions' => 'Message actions',
			'conversazione.viewOriginal' => 'View original',
			'conversazione.originalTitle' => 'Original message',
			'conversazione.linkWarningTitle' => 'This link goes to a different site',
			'conversazione.linkWarningBody' => ({required Object domain}) => 'The link\'s text shows an address other than the real one. If you open it, you go to ${domain}.',
			'conversazione.linkUnverifiedBody' => ({required Object domain}) => 'Where this link goes cannot be verified. If you open it, you go to ${domain}.',
			'conversazione.linkWarningPunycode' => 'The site\'s name uses special characters (punycode): it may imitate another one.',
			'conversazione.linkOpen' => 'Open the link',
			'conversazione.linkCancel' => 'Don\'t open',
			'composizione.title' => 'New message',
			'composizione.write' => 'Compose',
			'composizione.from' => 'From',
			'composizione.to' => 'To',
			'composizione.cc' => 'Cc',
			'composizione.bcc' => 'Bcc',
			'composizione.subject' => 'Subject',
			'composizione.body' => 'Write your message',
			'composizione.close' => 'Close',
			'composizione.bold' => 'Bold',
			'composizione.italic' => 'Italic',
			'composizione.underline' => 'Underline',
			'composizione.strikethrough' => 'Strikethrough',
			'composizione.link' => 'Link',
			'composizione.bulletList' => 'Bulleted list',
			'composizione.numberedList' => 'Numbered list',
			'composizione.linkUrl' => 'Link address',
			'composizione.insert' => 'Insert',
			'composizione.cancel' => 'Cancel',
			'composizione.editor' => 'Message body',
			'composizione.draftNotFound' => 'Draft not found',
			'composizione.draftWithAttachments' => 'This draft has attachments: edit it from the client that created it',
			'composizione.draftReply' => 'This Draft is a reply: edit it from the client that created it',
			'composizione.send' => 'Send',
			'composizione.queued' => 'Waiting to send',
			'composizione.undo' => 'Undo',
			'composizione.tooLarge' => ({required Object mb}) => 'The message exceeds Gmail\'s ${mb} MB limit',
			'composizione.sendFailed' => 'Sending failed: try again',
			'composizione.offlineAttachments' => 'You are offline: the forwarded attachments are not downloaded yet, try again online',
			'composizione.noRecipient' => 'Add at least one recipient',
			'composizione.forwardedAttachments' => 'Attachments',
			'bozze.title' => 'Drafts',
			'bozze.emptyTitle' => 'No drafts',
			'bozze.emptyBody' => 'Drafts you write stay here until you send them.',
			'inviati.title' => 'Sent',
			'inviati.waiting' => 'Waiting to send',
			'inviati.offline' => 'Outgoing, waiting for network',
			'inviati.failed' => 'Sending failed',
			'inviati.emptyTitle' => 'No sent messages',
			'inviati.emptyBody' => 'Messages you send show up here.',
			'impostazioni.title' => 'Settings',
			'impostazioni.deviceSection' => 'Device',
			'impostazioni.device' => 'Device settings',
			'impostazioni.launchAtLogin' => 'Launch at login',
			'impostazioni.launchAtLoginBody' => 'Postino opens when you log in and stays in the tray, so mail keeps arriving.',
			'impostazioni.launchAtLoginFailed' => 'The system did not accept the change. Try again, or check the login items in the system settings.',
			'impostazioni.syncSection' => 'Sync',
			'impostazioni.syncTitle' => 'Sync to…',
			'impostazioni.syncNone' => 'None',
			'impostazioni.syncBody' => 'Postino\'s settings (for example the automatic labels) are saved in a hidden file in the Google Drive of the Account you choose, without credentials. Postino asks Google for access to that hidden Drive space, not to your files.',
			'impostazioni.syncChooserTitle' => 'Sync settings to',
			'impostazioni.syncCancel' => 'Cancel',
			'impostazioni.syncBusy' => 'Connecting to Drive…',
			'impostazioni.syncDenied' => 'Google did not grant access to the hidden Drive space. Syncing stays as it was.',
			'impostazioni.syncWrongAccount' => ({required Object address}) => 'You picked another Google account. Pick ${address}.',
			'impostazioni.syncOffline' => 'You are offline. Try again when the network is back.',
			'impostazioni.syncFailed' => 'Could not connect Drive. Try again.',
			'tray.open' => 'Open Postino',
			'tray.quit' => 'Quit',
			'selettoreEtichette.button' => 'Labels',
			'selettoreEtichette.menuItem' => 'Labels…',
			'selettoreEtichette.close' => 'Close labels',
			'selettoreEtichette.search' => 'Search or create a label',
			'selettoreEtichette.nestHelp' => 'Use “/” to nest it, e.g. Projects/Postino.',
			'selettoreEtichette.create' => ({required Object name}) => 'Create “${name}”',
			'selettoreEtichette.selected' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, zero: 'Labels, none selected', one: 'Labels, ${n} selected', other: 'Labels, ${n} selected', ), 
			'selettoreEtichette.empty' => 'No labels',
			'selettoreEtichette.removed' => ({required Object name}) => 'Label “${name}” removed',
			'selettoreEtichette.undo' => 'Undo',
			'selettoreEtichette.remove' => ({required Object name}) => 'Remove label ${name}',
			'selettoreEtichette.errorEmpty' => 'Type a name for the label.',
			'selettoreEtichette.errorEmptyLevel' => 'Every level needs a name: no “/” at the start, at the end or doubled.',
			'selettoreEtichette.errorDuplicate' => 'A label with this name already exists.',
			'etichetteAutomatiche.title' => 'Automatic labels',
			'etichetteAutomatiche.page' => ({required Object account}) => 'Settings · ${account}',
			'etichetteAutomatiche.intro' => 'A model running on your device assigns labels to incoming email.\nIt only applies to new email that arrives after you turn it on.\nEach email gets at most one label, and email that already has one is skipped.\nThe label is written to Gmail.',
			'etichetteAutomatiche.labels' => 'Labels',
			'etichetteAutomatiche.empty' => 'No labels: create one to start.',
			'etichetteAutomatiche.automatic' => 'Automatic',
			'etichetteAutomatiche.description' => 'Description (optional)',
			'etichetteAutomatiche.descriptionHelp' => 'Describe which email goes here, e.g. invoices and receipts from suppliers',
			'etichetteAutomatiche.descriptionSaved' => 'Description saved',
			'etichetteAutomatiche.create' => 'Create label',
			'etichetteAutomatiche.createTitle' => 'Create label',
			'etichetteAutomatiche.createName' => 'Label name',
			'etichetteAutomatiche.createHelp' => 'Use “/” to nest it, e.g. Projects/Postino.',
			'etichetteAutomatiche.createAction' => 'Create',
			'etichetteAutomatiche.createCancel' => 'Cancel',
			'etichetteAutomatiche.createFailed' => 'The label could not be created. Check your connection and try again.',
			'etichetteAutomatiche.errorEmpty' => 'Type a name for the label.',
			'etichetteAutomatiche.errorEmptyLevel' => 'Every level needs a name: no “/” at the start, at the end or doubled.',
			'etichetteAutomatiche.errorDuplicate' => 'A label with this name already exists.',
			'etichetteAutomatiche.model.preparing' => 'Preparing the model',
			'etichetteAutomatiche.model.waitingTitle' => 'Waiting for Wi-Fi',
			'etichetteAutomatiche.model.waitingBody' => ({required Object size}) => 'The model (${size}) downloads when you are on Wi-Fi.',
			'etichetteAutomatiche.model.downloadNow' => 'Download now',
			'etichetteAutomatiche.model.downloading' => 'Downloading the model',
			'etichetteAutomatiche.model.progress' => ({required Object received, required Object total, required Object percent}) => '${received} of ${total} · ${percent}%',
			'etichetteAutomatiche.model.failedTitle' => 'Model download failed',
			'etichetteAutomatiche.model.failedOffline' => 'Connection lost.',
			'etichetteAutomatiche.model.failedOther' => 'Unexpected error.',
			'etichetteAutomatiche.model.retry' => 'Retry',
			'etichetteAutomatiche.model.ready' => 'Model ready',
			'etichetteAutomatiche.model.readyBody' => 'New email gets automatic labels.',
			'etichetteAutomatiche.model.readySnackbar' => 'Automatic labels ready',
			'etichetteAutomatiche.model.dismiss' => 'OK',
			'etichetteAutomatiche.model.confirmTitle' => ({required Object size}) => 'Download ${size} over cellular?',
			'etichetteAutomatiche.model.confirmWait' => 'Wait for Wi-Fi',
			'notifiche.channel' => 'New mail',
			'notifiche.open' => 'Open',
			'notifiche.permissionTitle' => 'New mail notifications',
			'notifiche.permissionBody' => 'Postino lets you know when a message arrives, with its sender, subject and preview. The system will ask for your permission.',
			'notifiche.permissionAllow' => 'Continue',
			'notifiche.permissionLater' => 'Not now',
			_ => null,
		};
	}
}
