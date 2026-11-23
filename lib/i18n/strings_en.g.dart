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
	@override String drawerAccount({required Object address}) => 'Account ${address}';
	@override String get cestino => 'Trash';
	@override late final _Translations$onboarding$en onboarding = _Translations$onboarding$en._(_root);
	@override late final _Translations$daRicollegare$en daRicollegare = _Translations$daRicollegare$en._(_root);
	@override late final _Translations$connect$en connect = _Translations$connect$en._(_root);
	@override late final _Translations$aggiornamenti$en aggiornamenti = _Translations$aggiornamenti$en._(_root);
	@override late final _Translations$offline$en offline = _Translations$offline$en._(_root);
	@override late final _Translations$syncStatus$en syncStatus = _Translations$syncStatus$en._(_root);
	@override late final _Translations$list$en list = _Translations$list$en._(_root);
	@override late final _Translations$sezioni$en sezioni = _Translations$sezioni$en._(_root);
	@override late final _Translations$conversazione$en conversazione = _Translations$conversazione$en._(_root);
	@override late final _Translations$composizione$en composizione = _Translations$composizione$en._(_root);
	@override late final _Translations$bozze$en bozze = _Translations$bozze$en._(_root);
	@override late final _Translations$inviati$en inviati = _Translations$inviati$en._(_root);
	@override late final _Translations$impostazioni$en impostazioni = _Translations$impostazioni$en._(_root);
	@override late final _Translations$segnalazione$en segnalazione = _Translations$segnalazione$en._(_root);
	@override late final _Translations$tray$en tray = _Translations$tray$en._(_root);
	@override late final _Translations$selettoreEtichette$en selettoreEtichette = _Translations$selettoreEtichette$en._(_root);
	@override late final _Translations$etichetteAutomatiche$en etichetteAutomatiche = _Translations$etichetteAutomatiche$en._(_root);
	@override late final _Translations$notifiche$en notifiche = _Translations$notifiche$en._(_root);
	@override late final _Translations$cerca$en cerca = _Translations$cerca$en._(_root);
	@override late final _Translations$conflitti$en conflitti = _Translations$conflitti$en._(_root);
	@override late final _Translations$azioni$en azioni = _Translations$azioni$en._(_root);
	@override late final _Translations$scorrimento$en scorrimento = _Translations$scorrimento$en._(_root);
	@override late final _Translations$passwordForm$en passwordForm = _Translations$passwordForm$en._(_root);
	@override late final _Translations$accounts$en accounts = _Translations$accounts$en._(_root);
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
	@override String get connectOutlook => 'Connect Outlook';
	@override String get connectIcloud => 'Connect iCloud';
	@override String get connectImap => 'Other IMAP';
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
	@override String get microsoftMessage => 'Microsoft no longer accepts the sign-in. Mail stays readable but won\'t update until you sign in.';
	@override String get passwordMessage => 'The server no longer accepts the password. Your mail stays readable but won\'t update until you sign in.';
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
	@override String get missingPermissionMicrosoft => 'Permission to read and send your mail is required: try again and keep it ticked.';
	@override String wrongAccount({required Object address}) => 'You picked a different account: to reconnect ${address}, pick that account.';
	@override String get failed => 'Something went wrong: try again.';
	@override String get alreadyConnected => 'This Account is already connected.';
	@override String get adminConsent => 'Your organization requires an administrator\'s approval to use Postino.';
	@override String get organizationPolicy => 'Your organization does not allow sign-in from this app or this device.';
}

// Path: aggiornamenti
class _Translations$aggiornamenti$en extends Translations$aggiornamenti$it {
	_Translations$aggiornamenti$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String available({required Object version}) => 'Postino ${version} is available';
	@override String get update => 'Update';
	@override String get dismiss => 'Dismiss';
}

// Path: offline
class _Translations$offline$en extends Translations$offline$it {
	_Translations$offline$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'You\'re offline';
	@override String get message => 'Mail will update when the network is back.';
}

// Path: syncStatus
class _Translations$syncStatus$en extends Translations$syncStatus$it {
	_Translations$syncStatus$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get running => 'Syncing…';
	@override String get now => 'Updated just now';
	@override String minutesAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Updated ${n} minute ago',
		other: 'Updated ${n} minutes ago',
	);
	@override String at({required Object time}) => 'Updated at ${time}';
	@override String on({required Object date}) => 'Updated on ${date}';
	@override String get offline => 'Offline';
	@override String offlineAt({required Object time}) => 'Offline · updated at ${time}';
	@override String offlineOn({required Object date}) => 'Offline · updated on ${date}';
	@override String get failed => 'Couldn\'t update';
	@override String get retry => 'Retry';
	@override String get refresh => 'Refresh mail';
	@override String get done => 'Mail updated';
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

// Path: sezioni
class _Translations$sezioni$en extends Translations$sezioni$it {
	_Translations$sezioni$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get starred => 'Starred';
	@override String get unread => 'Unread';
	@override String get read => 'Read';
	@override String heading({required num n, required Object title}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${title}, ${n} conversation',
		other: '${title}, ${n} conversations',
	);
	@override String get showAll => 'Show all';
	@override String showAllLabel({required Object n, required Object title}) => 'Show all ${n} ${title}';
	@override String get scopeAll => 'all';
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
	@override String tooLarge({required Object mb}) => 'The message exceeds the ${mb} MB limit of the Provider';
	@override String get sendFailed => 'Sending failed: try again';
	@override String get offlineAttachments => 'You are offline: the forwarded attachments are not downloaded yet, try again online';
	@override String get noRecipient => 'Add at least one recipient';
	@override String get forwardedAttachments => 'Attachments';
	@override String suggestions({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} suggestion',
		other: '${n} suggestions',
	);
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
	@override String get immediateNotifications => 'Immediate notifications';
	@override String get immediateNotificationsBody => 'New mail arrives in real time, even with Postino closed. In exchange a fixed notification stays and Postino asks not to be limited by battery optimization: it uses more battery. Off, new mail is checked about every 15 minutes.';
	@override String get immediateNotificationsBodySettings => 'New mail arrives in real time, even with Postino closed. In exchange a fixed notification stays and Postino opens the battery optimization settings, where you choose not to optimize Postino: it uses more battery. Off, new mail is checked about every 15 minutes.';
	@override String get immediateNotificationsFailed => 'The system did not start the immediate notifications. Try again.';
	@override String get checkForUpdates => 'Check for updates';
	@override String get checkForUpdatesBody => 'Look for a new version of Postino now.';
	@override String get privacy => 'Privacy policy';
	@override String versionLabel({required Object version, required Object build}) => 'Postino ${version} (build ${build})';
	@override String get versionDevelopment => 'Postino · development';
	@override String get upToDate => 'Postino is up to date.';
	@override String get checkFound => 'A new version of Postino is available.';
	@override String get notifications => 'Notifications';
	@override String get notificationsAllowed => 'Allowed';
	@override String get notificationsDenied => 'Not allowed: new mail arrives without an alert.';
	@override String get notificationsAllow => 'Allow';
	@override String get notificationActionFirst => 'First notification action';
	@override String get notificationActionSecond => 'Second notification action';
	@override String get notificationActionNone => 'None';
	@override String get syncSection => 'Sync';
	@override String get syncTitle => 'Sync to…';
	@override String get syncNone => 'None';
	@override String get syncBody => 'Postino\'s settings (for example the automatic labels) and the Accounts\' credentials are saved encrypted in a hidden file in the Google Drive of the Account you choose. The key stays on your devices. Postino asks Google for access to that hidden Drive space, not to your files.';
	@override String get syncChooserTitle => 'Sync settings to';
	@override String get syncCancel => 'Cancel';
	@override String get syncBusy => 'Connecting to Drive…';
	@override String get syncDenied => 'Google did not grant access to the hidden Drive space. Syncing stays as it was.';
	@override String syncWrongAccount({required Object address}) => 'You picked another Google account. Pick ${address}.';
	@override String get syncOffline => 'You are offline. Try again when the network is back.';
	@override String get syncFailed => 'Could not connect Drive. Try again.';
	@override String syncDoneAt({required Object time}) => 'Settings synced at ${time}';
	@override String syncDoneOn({required Object date}) => 'Settings synced on ${date}';
	@override String get syncCycleFailed => 'Settings not synced';
	@override String get syncCycleScope => 'Google no longer grants access to the hidden Drive space: pick the Account again in “Sync to…”.';
	@override String syncCycleReason({required Object reason}) => 'Reason: ${reason}';
	@override String get syncPairOther => 'Pair another device';
	@override String get syncPairOtherSubtitle => 'Shows the code to enter on the new device';
	@override String get syncPairShowBody => 'On the new device connect this same Account, pick it in “Sync to…”, then scan this QR, or type or paste the code. Whoever has the code can read the synced settings: do not share it.';
	@override String get syncPairQrLabel => 'QR of the pairing code';
	@override String get syncPairCodeLabel => 'Pairing code';
	@override String syncPairClosesIn({required Object time}) => 'Closes in ${time}';
	@override String syncPairClosesInSeconds({required Object seconds}) => 'The code closes in ${seconds} seconds';
	@override String get syncPairCaptured => 'The code is hidden while the screen is recorded or mirrored.';
	@override String get syncPairClose => 'Close';
	@override String get syncPairNoKey => 'Nothing to pair yet: this device\'s settings have not been synced yet.';
	@override String get syncPairEnter => 'Enter the code';
	@override String get syncPairEnterTitle => 'Pair this device';
	@override String get syncPairEnterBody => 'On a device already paired open “Sync to…” › “Pair another device”, then type or paste the code here. Both devices must sync to the same Account.';
	@override String get syncPairEnterField => 'Pairing code';
	@override String get syncPairEnterHelper => 'It starts with P1. Spaces and dashes do not matter.';
	@override String get syncPairEnterConfirm => 'Pair';
	@override String get syncPairEnterCancel => 'Cancel';
	@override String get syncPairScan => 'Scan the QR';
	@override String get syncPairScanBody => 'Point the camera at the QR the paired device shows in “Sync to…” › “Pair another device”.';
	@override String get syncPairScanPreview => 'Camera viewfinder';
	@override String get syncPairScanInvalid => 'This QR is not a valid pairing code. Scan the one in “Pair another device”, on a device that syncs to the same Account in “Sync to…”.';
	@override String get syncPairCameraDenied => 'Postino may not use the camera. Allow it in the system settings, or type the code.';
	@override String get syncPairCameraUnavailable => 'The camera is not available. Type the code.';
	@override String get syncPairType => 'Type the code';
	@override String get syncPairBusy => 'Checking the code…';
	@override String get syncPairInvalid => 'Invalid code. Check you copied all of it, and that both devices sync to the same Account in “Sync to…”.';
	@override String get syncPairNothing => 'There are no encrypted settings on Drive to pair with yet: this device makes its own key at its first sync.';
	@override String syncPairFailed({required Object reason}) => 'Pairing failed. Reason: ${reason}';
	@override String get syncPairNeededTitle => 'This device is not paired';
	@override String get syncPairNeededBody => 'The settings on Drive are encrypted. Pair it with the code of a device that syncs to this Account: until then the changes stay here.';
	@override String get syncKeyInvalidTitle => 'Sync key no longer valid';
	@override String get syncKeyInvalidBody => 'The settings on Drive are encrypted with another key. Pair this device again: the changes made here stay and upload afterwards.';
	@override String get syncRegenerate => 'Regenerate the key';
	@override String get syncRegenerateSubtitle => 'The other devices will have to be paired again';
	@override String get syncRegenerateTitle => 'Regenerate the sync key?';
	@override String get syncRegenerateMessage => 'Postino makes a new key and encrypts the settings on Drive with it. The other devices will have to be paired again.';
	@override String get syncRegenerateNote => 'If the settings on Drive can be read, they are merged with this device\'s first. If they cannot (key lost or file damaged), they are replaced by this device\'s: what was on Drive and is not here is lost.';
	@override String get syncRegenerateConfirm => 'Regenerate';
	@override String get syncRegenerateCancel => 'Cancel';
}

// Path: segnalazione
class _Translations$segnalazione$en extends Translations$segnalazione$it {
	_Translations$segnalazione$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get action => 'Report a problem';
	@override String get subject => 'Problem in Postino';
	@override String get intro => 'Describe here what went wrong. Below is Postino\'s error log: it has no passwords or tokens, read it before sending.';
	@override String get crashTitle => 'Postino closed unexpectedly';
	@override String get crashBody => 'Do you want to report the problem? A draft opens with the error log: you read it and decide whether to send it.';
	@override String get crashConfirm => 'Report';
	@override String get crashDismiss => 'Not now';
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
	@override String newMessages({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} new message',
		other: '${n} new messages',
	);
	@override String get listeningChannel => 'Postino listening';
	@override String get listeningTitle => 'Postino is listening';
	@override String get listeningText => 'New mail arrives in real time. Tap to open All inboxes.';
}

// Path: cerca
class _Translations$cerca$en extends Translations$cerca$it {
	_Translations$cerca$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get open => 'Search';
	@override String get title => 'Search';
	@override String get field => 'Search mail';
	@override String get fieldTrash => 'Search the Trash';
	@override String get scopeAll => 'All Accounts';
	@override String get idleTitle => 'Search your mail';
	@override String get idleBody => 'Type a word, or use from:, to: and subject: for sender, recipients and subject. Quotes search for a phrase. Narrow down with is:unread, is:starred, has:attachment, after:2026-01-31, before:2026-02-28 and account:name.';
	@override String get emptyTitle => 'No results';
	@override String get emptyBody => 'Try other words, or just the start of a word.';
	@override String results({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} result',
		other: '${n} results',
	);
	@override late final _Translations$cerca$provider$en provider = _Translations$cerca$provider$en._(_root);
}

// Path: conflitti
class _Translations$conflitti$en extends Translations$conflitti$it {
	_Translations$conflitti$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String bannerTitle({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} conflict',
		other: '${n} conflicts',
	);
	@override String get bannerMessage => 'You changed some messages offline, and they changed somewhere else too.';
	@override String get open => 'Review';
	@override String get title => 'Conflicts';
	@override String get emptyTitle => 'No conflicts';
	@override String get emptyBody => 'When a message changes in two places, you\'ll find it here.';
	@override String get keepMine => 'Yours';
	@override String get keepProvider => 'Provider\'s';
	@override String mine({required Object value}) => 'Yours: ${value}';
	@override String provider({required Object value}) => 'Provider: ${value}';
	@override String get sign => 'Conflict';
	@override String signFor({required Object sender, required Object time}) => 'Conflict: ${sender}, ${time}';
	@override String get signMessage => 'This message changed somewhere else too. You see your version here.';
	@override String account({required Object name}) => 'account ${name}';
	@override String get noSubject => '(no subject)';
	@override String get draft => 'Draft';
	@override String draftMine({required Object subject, required Object body}) => 'Your version: subject ${subject}, text ${body}';
	@override String draftProvider({required Object subject, required Object body}) => 'Provider\'s version: subject ${subject}, text ${body}';
	@override late final _Translations$conflitti$values$en values = _Translations$conflitti$values$en._(_root);
}

// Path: azioni
class _Translations$azioni$en extends Translations$azioni$it {
	_Translations$azioni$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get archive => 'Archive';
	@override String get delete => 'Delete';
	@override String get star => 'Star';
	@override String get unstar => 'Remove star';
	@override String get markRead => 'Mark as read';
	@override String get markUnread => 'Mark as unread';
	@override String get archived => 'Conversation archived';
	@override String get deleted => 'Conversation moved to Trash';
	@override String labelApplied({required Object name}) => 'Label “${name}” applied';
	@override String get undo => 'Undo';
	@override String get more => 'More actions';
	@override String get applyLabel => 'Apply Label';
}

// Path: scorrimento
class _Translations$scorrimento$en extends Translations$scorrimento$it {
	_Translations$scorrimento$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Swipe actions';
	@override String get intro => 'Swiping a row of the list runs an Action. The choice applies to all Accounts.';
	@override String get left => 'Swipe left';
	@override String get right => 'Swipe right';
	@override String get markRead => 'Mark as read/unread';
	@override String get star => 'Star';
}

// Path: passwordForm
class _Translations$passwordForm$en extends Translations$passwordForm$it {
	_Translations$passwordForm$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get icloudTitle => 'Connect iCloud';
	@override String get imapTitle => 'Connect an IMAP Account';
	@override String get reconnectTitle => 'Reconnect the Account';
	@override String get address => 'Email address';
	@override String get password => 'Password';
	@override String get appPassword => 'App-specific password';
	@override String get icloudHelp => 'iCloud needs an app-specific password, not your Apple Account password.';
	@override String get appleLink => 'How to create an app-specific password';
	@override String get manual => 'Set up the servers manually';
	@override String get imapServer => 'IMAP server (incoming mail)';
	@override String get smtpServer => 'SMTP server (outgoing mail)';
	@override String get host => 'Host';
	@override String get port => 'Port';
	@override String get ssl => 'SSL/TLS';
	@override String get starttls => 'STARTTLS';
	@override String get connect => 'Connect';
	@override String get cancel => 'Cancel';
	@override String get connecting => 'Checking the connection';
	@override String get invalidAddress => 'Enter a full email address.';
	@override String get emptyPassword => 'Enter the password.';
	@override String get invalidHost => 'Enter the server host.';
	@override String get invalidPort => 'Enter a port between 1 and 65535.';
	@override String get authRejected => 'The server refused the address or the password.';
	@override String get serverNotFound => 'Couldn\'t find the servers for this address: enter them below.';
	@override String get unreachable => 'Server unreachable: check the connection, the host and the port.';
	@override String get alreadyConnected => 'This Account is already connected.';
	@override String get useGmail => 'For a Gmail address use «Connect Gmail».';
	@override String get useMicrosoft => 'For an Outlook.com, Hotmail, Live, MSN or Microsoft 365 work or school address use «Connect Outlook».';
}

// Path: accounts
class _Translations$accounts$en extends Translations$accounts$it {
	_Translations$accounts$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get section => 'Accounts';
	@override String get add => 'Add Account';
	@override String get gmail => 'Gmail';
	@override String get icloud => 'iCloud';
	@override String get imap => 'IMAP';
	@override String get microsoft => 'Microsoft';
	@override String remove({required Object address}) => 'Remove the Account ${address}';
	@override String removeTitle({required Object name}) => 'Remove the Account ${name}?';
	@override String get removeMessage => 'The emails downloaded on this device are deleted; on the server they stay as they are.';
	@override String get removeNote => 'Changes not yet sent to the server are lost.';
	@override String get removeGmailNote => 'Postino stays among the apps authorized in your Google account: you can remove it in your Google account settings.';
	@override String get removeSyncedNote => 'The Account and its access are removed from all paired devices.';
	@override String get removeConfirm => 'Remove';
	@override String get removeCancel => 'Cancel';
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

// Path: cerca.provider
class _Translations$cerca$provider$en extends Translations$cerca$provider$it {
	_Translations$cerca$provider$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String searching({required Object name}) => 'Also searching ${name}…';
	@override String unreachable({required Object name}) => 'Local results only: ${name} can\'t be reached';
	@override String capped({required Object n, required Object name}) => 'Showing the first ${n} results from ${name}';
	@override String get retry => 'Press Enter in the field to try again.';
	@override String get more => 'Show more';
	@override String get reconnect => 'It needs to be reconnected: sign in again from the notice in the mail list.';
	@override String get later => 'The provider asked for a pause: try again in a few minutes.';
}

// Path: conflitti.values
class _Translations$conflitti$values$en extends Translations$conflitti$values$it {
	_Translations$conflitti$values$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get read => 'read';
	@override String get unread => 'unread';
	@override String get starred => 'starred';
	@override String get unstarred => 'not starred';
	@override String get inbox => 'in the inbox';
	@override String get archive => 'archived';
	@override String get trash => 'in the Trash';
	@override String labeled({required Object name}) => 'labelled ${name}';
	@override String unlabeled({required Object name}) => 'not labelled ${name}';
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
			'drawerAccount' => ({required Object address}) => 'Account ${address}',
			'cestino' => 'Trash',
			'onboarding.body' => 'All your mailboxes in one place.',
			'onboarding.connectGmail' => 'Connect Gmail',
			'onboarding.connectOutlook' => 'Connect Outlook',
			'onboarding.connectIcloud' => 'Connect iCloud',
			'onboarding.connectImap' => 'Other IMAP',
			'daRicollegare.title' => ({required Object name}) => '${name} needs signing in again',
			'daRicollegare.message' => 'Google no longer accepts the sign-in. Mail stays readable but won\'t update until you sign in.',
			'daRicollegare.signIn' => 'Sign in',
			'daRicollegare.status' => 'Needs signing in',
			'daRicollegare.microsoftMessage' => 'Microsoft no longer accepts the sign-in. Mail stays readable but won\'t update until you sign in.',
			'daRicollegare.passwordMessage' => 'The server no longer accepts the password. Your mail stays readable but won\'t update until you sign in.',
			'connect.title' => 'Couldn\'t connect',
			'connect.missingSetting' => ({required Object setting}) => '${setting} is missing: start Postino with --dart-define=${setting}=… (see README).',
			'connect.offline' => 'No connection: try again when you are online.',
			'connect.missingPermission' => 'Gmail access is required: try again and keep the permission to read and manage your mail ticked.',
			'connect.missingPermissionMicrosoft' => 'Permission to read and send your mail is required: try again and keep it ticked.',
			'connect.wrongAccount' => ({required Object address}) => 'You picked a different account: to reconnect ${address}, pick that account.',
			'connect.failed' => 'Something went wrong: try again.',
			'connect.alreadyConnected' => 'This Account is already connected.',
			'connect.adminConsent' => 'Your organization requires an administrator\'s approval to use Postino.',
			'connect.organizationPolicy' => 'Your organization does not allow sign-in from this app or this device.',
			'aggiornamenti.available' => ({required Object version}) => 'Postino ${version} is available',
			'aggiornamenti.update' => 'Update',
			'aggiornamenti.dismiss' => 'Dismiss',
			'offline.title' => 'You\'re offline',
			'offline.message' => 'Mail will update when the network is back.',
			'syncStatus.running' => 'Syncing…',
			'syncStatus.now' => 'Updated just now',
			'syncStatus.minutesAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Updated ${n} minute ago', other: 'Updated ${n} minutes ago', ), 
			'syncStatus.at' => ({required Object time}) => 'Updated at ${time}',
			'syncStatus.on' => ({required Object date}) => 'Updated on ${date}',
			'syncStatus.offline' => 'Offline',
			'syncStatus.offlineAt' => ({required Object time}) => 'Offline · updated at ${time}',
			'syncStatus.offlineOn' => ({required Object date}) => 'Offline · updated on ${date}',
			'syncStatus.failed' => 'Couldn\'t update',
			'syncStatus.retry' => 'Retry',
			'syncStatus.refresh' => 'Refresh mail',
			'syncStatus.done' => 'Mail updated',
			'list.loading' => 'Loading messages',
			'list.emptyTitle' => 'Nothing new',
			'list.emptyBody' => 'Messages show up here as they arrive.',
			'list.yesterday' => 'Yesterday',
			'list.unread' => 'Unread',
			'list.starred' => 'starred',
			'list.account' => ({required Object name}) => 'account ${name}',
			'list.messages' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} message', other: '${n} messages', ), 
			'sezioni.starred' => 'Starred',
			'sezioni.unread' => 'Unread',
			'sezioni.read' => 'Read',
			'sezioni.heading' => ({required num n, required Object title}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${title}, ${n} conversation', other: '${title}, ${n} conversations', ), 
			'sezioni.showAll' => 'Show all',
			'sezioni.showAllLabel' => ({required Object n, required Object title}) => 'Show all ${n} ${title}',
			'sezioni.scopeAll' => 'all',
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
			'composizione.tooLarge' => ({required Object mb}) => 'The message exceeds the ${mb} MB limit of the Provider',
			'composizione.sendFailed' => 'Sending failed: try again',
			'composizione.offlineAttachments' => 'You are offline: the forwarded attachments are not downloaded yet, try again online',
			'composizione.noRecipient' => 'Add at least one recipient',
			'composizione.forwardedAttachments' => 'Attachments',
			'composizione.suggestions' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} suggestion', other: '${n} suggestions', ), 
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
			'impostazioni.immediateNotifications' => 'Immediate notifications',
			'impostazioni.immediateNotificationsBody' => 'New mail arrives in real time, even with Postino closed. In exchange a fixed notification stays and Postino asks not to be limited by battery optimization: it uses more battery. Off, new mail is checked about every 15 minutes.',
			'impostazioni.immediateNotificationsBodySettings' => 'New mail arrives in real time, even with Postino closed. In exchange a fixed notification stays and Postino opens the battery optimization settings, where you choose not to optimize Postino: it uses more battery. Off, new mail is checked about every 15 minutes.',
			'impostazioni.immediateNotificationsFailed' => 'The system did not start the immediate notifications. Try again.',
			'impostazioni.checkForUpdates' => 'Check for updates',
			'impostazioni.checkForUpdatesBody' => 'Look for a new version of Postino now.',
			'impostazioni.privacy' => 'Privacy policy',
			'impostazioni.versionLabel' => ({required Object version, required Object build}) => 'Postino ${version} (build ${build})',
			'impostazioni.versionDevelopment' => 'Postino · development',
			'impostazioni.upToDate' => 'Postino is up to date.',
			'impostazioni.checkFound' => 'A new version of Postino is available.',
			'impostazioni.notifications' => 'Notifications',
			'impostazioni.notificationsAllowed' => 'Allowed',
			'impostazioni.notificationsDenied' => 'Not allowed: new mail arrives without an alert.',
			'impostazioni.notificationsAllow' => 'Allow',
			'impostazioni.notificationActionFirst' => 'First notification action',
			'impostazioni.notificationActionSecond' => 'Second notification action',
			'impostazioni.notificationActionNone' => 'None',
			'impostazioni.syncSection' => 'Sync',
			'impostazioni.syncTitle' => 'Sync to…',
			'impostazioni.syncNone' => 'None',
			'impostazioni.syncBody' => 'Postino\'s settings (for example the automatic labels) and the Accounts\' credentials are saved encrypted in a hidden file in the Google Drive of the Account you choose. The key stays on your devices. Postino asks Google for access to that hidden Drive space, not to your files.',
			'impostazioni.syncChooserTitle' => 'Sync settings to',
			'impostazioni.syncCancel' => 'Cancel',
			'impostazioni.syncBusy' => 'Connecting to Drive…',
			'impostazioni.syncDenied' => 'Google did not grant access to the hidden Drive space. Syncing stays as it was.',
			'impostazioni.syncWrongAccount' => ({required Object address}) => 'You picked another Google account. Pick ${address}.',
			'impostazioni.syncOffline' => 'You are offline. Try again when the network is back.',
			'impostazioni.syncFailed' => 'Could not connect Drive. Try again.',
			'impostazioni.syncDoneAt' => ({required Object time}) => 'Settings synced at ${time}',
			'impostazioni.syncDoneOn' => ({required Object date}) => 'Settings synced on ${date}',
			'impostazioni.syncCycleFailed' => 'Settings not synced',
			'impostazioni.syncCycleScope' => 'Google no longer grants access to the hidden Drive space: pick the Account again in “Sync to…”.',
			'impostazioni.syncCycleReason' => ({required Object reason}) => 'Reason: ${reason}',
			'impostazioni.syncPairOther' => 'Pair another device',
			'impostazioni.syncPairOtherSubtitle' => 'Shows the code to enter on the new device',
			'impostazioni.syncPairShowBody' => 'On the new device connect this same Account, pick it in “Sync to…”, then scan this QR, or type or paste the code. Whoever has the code can read the synced settings: do not share it.',
			'impostazioni.syncPairQrLabel' => 'QR of the pairing code',
			'impostazioni.syncPairCodeLabel' => 'Pairing code',
			'impostazioni.syncPairClosesIn' => ({required Object time}) => 'Closes in ${time}',
			'impostazioni.syncPairClosesInSeconds' => ({required Object seconds}) => 'The code closes in ${seconds} seconds',
			'impostazioni.syncPairCaptured' => 'The code is hidden while the screen is recorded or mirrored.',
			'impostazioni.syncPairClose' => 'Close',
			'impostazioni.syncPairNoKey' => 'Nothing to pair yet: this device\'s settings have not been synced yet.',
			'impostazioni.syncPairEnter' => 'Enter the code',
			'impostazioni.syncPairEnterTitle' => 'Pair this device',
			'impostazioni.syncPairEnterBody' => 'On a device already paired open “Sync to…” › “Pair another device”, then type or paste the code here. Both devices must sync to the same Account.',
			'impostazioni.syncPairEnterField' => 'Pairing code',
			'impostazioni.syncPairEnterHelper' => 'It starts with P1. Spaces and dashes do not matter.',
			'impostazioni.syncPairEnterConfirm' => 'Pair',
			'impostazioni.syncPairEnterCancel' => 'Cancel',
			'impostazioni.syncPairScan' => 'Scan the QR',
			'impostazioni.syncPairScanBody' => 'Point the camera at the QR the paired device shows in “Sync to…” › “Pair another device”.',
			'impostazioni.syncPairScanPreview' => 'Camera viewfinder',
			'impostazioni.syncPairScanInvalid' => 'This QR is not a valid pairing code. Scan the one in “Pair another device”, on a device that syncs to the same Account in “Sync to…”.',
			'impostazioni.syncPairCameraDenied' => 'Postino may not use the camera. Allow it in the system settings, or type the code.',
			'impostazioni.syncPairCameraUnavailable' => 'The camera is not available. Type the code.',
			'impostazioni.syncPairType' => 'Type the code',
			'impostazioni.syncPairBusy' => 'Checking the code…',
			'impostazioni.syncPairInvalid' => 'Invalid code. Check you copied all of it, and that both devices sync to the same Account in “Sync to…”.',
			'impostazioni.syncPairNothing' => 'There are no encrypted settings on Drive to pair with yet: this device makes its own key at its first sync.',
			'impostazioni.syncPairFailed' => ({required Object reason}) => 'Pairing failed. Reason: ${reason}',
			'impostazioni.syncPairNeededTitle' => 'This device is not paired',
			'impostazioni.syncPairNeededBody' => 'The settings on Drive are encrypted. Pair it with the code of a device that syncs to this Account: until then the changes stay here.',
			'impostazioni.syncKeyInvalidTitle' => 'Sync key no longer valid',
			'impostazioni.syncKeyInvalidBody' => 'The settings on Drive are encrypted with another key. Pair this device again: the changes made here stay and upload afterwards.',
			'impostazioni.syncRegenerate' => 'Regenerate the key',
			'impostazioni.syncRegenerateSubtitle' => 'The other devices will have to be paired again',
			'impostazioni.syncRegenerateTitle' => 'Regenerate the sync key?',
			'impostazioni.syncRegenerateMessage' => 'Postino makes a new key and encrypts the settings on Drive with it. The other devices will have to be paired again.',
			'impostazioni.syncRegenerateNote' => 'If the settings on Drive can be read, they are merged with this device\'s first. If they cannot (key lost or file damaged), they are replaced by this device\'s: what was on Drive and is not here is lost.',
			'impostazioni.syncRegenerateConfirm' => 'Regenerate',
			'impostazioni.syncRegenerateCancel' => 'Cancel',
			'segnalazione.action' => 'Report a problem',
			'segnalazione.subject' => 'Problem in Postino',
			'segnalazione.intro' => 'Describe here what went wrong. Below is Postino\'s error log: it has no passwords or tokens, read it before sending.',
			'segnalazione.crashTitle' => 'Postino closed unexpectedly',
			'segnalazione.crashBody' => 'Do you want to report the problem? A draft opens with the error log: you read it and decide whether to send it.',
			'segnalazione.crashConfirm' => 'Report',
			'segnalazione.crashDismiss' => 'Not now',
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
			'notifiche.newMessages' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} new message', other: '${n} new messages', ), 
			'notifiche.listeningChannel' => 'Postino listening',
			'notifiche.listeningTitle' => 'Postino is listening',
			'notifiche.listeningText' => 'New mail arrives in real time. Tap to open All inboxes.',
			'cerca.open' => 'Search',
			'cerca.title' => 'Search',
			'cerca.field' => 'Search mail',
			'cerca.fieldTrash' => 'Search the Trash',
			'cerca.scopeAll' => 'All Accounts',
			'cerca.idleTitle' => 'Search your mail',
			'cerca.idleBody' => 'Type a word, or use from:, to: and subject: for sender, recipients and subject. Quotes search for a phrase. Narrow down with is:unread, is:starred, has:attachment, after:2026-01-31, before:2026-02-28 and account:name.',
			'cerca.emptyTitle' => 'No results',
			'cerca.emptyBody' => 'Try other words, or just the start of a word.',
			'cerca.results' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} result', other: '${n} results', ), 
			'cerca.provider.searching' => ({required Object name}) => 'Also searching ${name}…',
			'cerca.provider.unreachable' => ({required Object name}) => 'Local results only: ${name} can\'t be reached',
			'cerca.provider.capped' => ({required Object n, required Object name}) => 'Showing the first ${n} results from ${name}',
			'cerca.provider.retry' => 'Press Enter in the field to try again.',
			'cerca.provider.more' => 'Show more',
			'cerca.provider.reconnect' => 'It needs to be reconnected: sign in again from the notice in the mail list.',
			'cerca.provider.later' => 'The provider asked for a pause: try again in a few minutes.',
			'conflitti.bannerTitle' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} conflict', other: '${n} conflicts', ), 
			'conflitti.bannerMessage' => 'You changed some messages offline, and they changed somewhere else too.',
			'conflitti.open' => 'Review',
			'conflitti.title' => 'Conflicts',
			'conflitti.emptyTitle' => 'No conflicts',
			'conflitti.emptyBody' => 'When a message changes in two places, you\'ll find it here.',
			'conflitti.keepMine' => 'Yours',
			'conflitti.keepProvider' => 'Provider\'s',
			'conflitti.mine' => ({required Object value}) => 'Yours: ${value}',
			'conflitti.provider' => ({required Object value}) => 'Provider: ${value}',
			'conflitti.sign' => 'Conflict',
			'conflitti.signFor' => ({required Object sender, required Object time}) => 'Conflict: ${sender}, ${time}',
			'conflitti.signMessage' => 'This message changed somewhere else too. You see your version here.',
			'conflitti.account' => ({required Object name}) => 'account ${name}',
			'conflitti.noSubject' => '(no subject)',
			'conflitti.draft' => 'Draft',
			'conflitti.draftMine' => ({required Object subject, required Object body}) => 'Your version: subject ${subject}, text ${body}',
			'conflitti.draftProvider' => ({required Object subject, required Object body}) => 'Provider\'s version: subject ${subject}, text ${body}',
			'conflitti.values.read' => 'read',
			'conflitti.values.unread' => 'unread',
			'conflitti.values.starred' => 'starred',
			'conflitti.values.unstarred' => 'not starred',
			'conflitti.values.inbox' => 'in the inbox',
			'conflitti.values.archive' => 'archived',
			'conflitti.values.trash' => 'in the Trash',
			'conflitti.values.labeled' => ({required Object name}) => 'labelled ${name}',
			'conflitti.values.unlabeled' => ({required Object name}) => 'not labelled ${name}',
			'azioni.archive' => 'Archive',
			'azioni.delete' => 'Delete',
			'azioni.star' => 'Star',
			'azioni.unstar' => 'Remove star',
			'azioni.markRead' => 'Mark as read',
			'azioni.markUnread' => 'Mark as unread',
			'azioni.archived' => 'Conversation archived',
			'azioni.deleted' => 'Conversation moved to Trash',
			'azioni.labelApplied' => ({required Object name}) => 'Label “${name}” applied',
			'azioni.undo' => 'Undo',
			'azioni.more' => 'More actions',
			'azioni.applyLabel' => 'Apply Label',
			'scorrimento.title' => 'Swipe actions',
			'scorrimento.intro' => 'Swiping a row of the list runs an Action. The choice applies to all Accounts.',
			'scorrimento.left' => 'Swipe left',
			'scorrimento.right' => 'Swipe right',
			'scorrimento.markRead' => 'Mark as read/unread',
			'scorrimento.star' => 'Star',
			'passwordForm.icloudTitle' => 'Connect iCloud',
			'passwordForm.imapTitle' => 'Connect an IMAP Account',
			'passwordForm.reconnectTitle' => 'Reconnect the Account',
			'passwordForm.address' => 'Email address',
			'passwordForm.password' => 'Password',
			'passwordForm.appPassword' => 'App-specific password',
			'passwordForm.icloudHelp' => 'iCloud needs an app-specific password, not your Apple Account password.',
			'passwordForm.appleLink' => 'How to create an app-specific password',
			'passwordForm.manual' => 'Set up the servers manually',
			'passwordForm.imapServer' => 'IMAP server (incoming mail)',
			'passwordForm.smtpServer' => 'SMTP server (outgoing mail)',
			'passwordForm.host' => 'Host',
			'passwordForm.port' => 'Port',
			'passwordForm.ssl' => 'SSL/TLS',
			'passwordForm.starttls' => 'STARTTLS',
			'passwordForm.connect' => 'Connect',
			'passwordForm.cancel' => 'Cancel',
			'passwordForm.connecting' => 'Checking the connection',
			'passwordForm.invalidAddress' => 'Enter a full email address.',
			'passwordForm.emptyPassword' => 'Enter the password.',
			'passwordForm.invalidHost' => 'Enter the server host.',
			'passwordForm.invalidPort' => 'Enter a port between 1 and 65535.',
			'passwordForm.authRejected' => 'The server refused the address or the password.',
			'passwordForm.serverNotFound' => 'Couldn\'t find the servers for this address: enter them below.',
			'passwordForm.unreachable' => 'Server unreachable: check the connection, the host and the port.',
			'passwordForm.alreadyConnected' => 'This Account is already connected.',
			'passwordForm.useGmail' => 'For a Gmail address use «Connect Gmail».',
			'passwordForm.useMicrosoft' => 'For an Outlook.com, Hotmail, Live, MSN or Microsoft 365 work or school address use «Connect Outlook».',
			'accounts.section' => 'Accounts',
			'accounts.add' => 'Add Account',
			'accounts.gmail' => 'Gmail',
			'accounts.icloud' => 'iCloud',
			'accounts.imap' => 'IMAP',
			'accounts.microsoft' => 'Microsoft',
			'accounts.remove' => ({required Object address}) => 'Remove the Account ${address}',
			'accounts.removeTitle' => ({required Object name}) => 'Remove the Account ${name}?',
			'accounts.removeMessage' => 'The emails downloaded on this device are deleted; on the server they stay as they are.',
			'accounts.removeNote' => 'Changes not yet sent to the server are lost.',
			'accounts.removeGmailNote' => 'Postino stays among the apps authorized in your Google account: you can remove it in your Google account settings.',
			'accounts.removeSyncedNote' => 'The Account and its access are removed from all paired devices.',
			'accounts.removeConfirm' => 'Remove',
			'accounts.removeCancel' => 'Cancel',
			_ => null,
		};
	}
}
