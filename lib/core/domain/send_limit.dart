import 'account.dart';

/// The biggest message Gmail sends: 35 MB of RFC 5322 text (`messages.send`).
const gmailSendLimitBytes = 36700160;

/// The biggest message Postino sends through Microsoft Graph in v1: 3 MB of RFC 5322 text, the size under which
/// `sendMail` takes the whole MIME in one request (`invio-posta-per-provider.md` §2: attachments up to 3 MB go in
/// one POST, larger ones need an upload session).
// ponytail: the ceiling of the simple path, not Graph's (150 MB per attachment with an upload session): bigger
// attachments come with #203 (upload session), once the real `sendMail` MIME limit and the Message-ID through
// that path are measured on an Outlook.com Account. Measured on the whole text, base64 included: under ~2.2 MB of files.
const microsoftSendLimitBytes = 3 * 1024 * 1024;

/// The biggest message [provider] accepts, null when only the server knows: IMAP/SMTP declares it (`SIZE`) when the
/// message is submitted. The one place where the limit is chosen per Provider.
int? sendLimitBytes(ProviderKind provider) => switch (provider) {
  ProviderKind.gmail => gmailSendLimitBytes,
  ProviderKind.microsoft => microsoftSendLimitBytes,
  ProviderKind.icloud || ProviderKind.imap => null,
};
