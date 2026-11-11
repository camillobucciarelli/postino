/// The Message-ID (RFC 5322) of the message with Provider id `id`, as the app remembers it; null if it does not.
/// How an Azione finds a message whose Provider id is gone (IMAP: its UID; Graph: an id that did not stay).
typedef MessageIdOf = Future<String?> Function(String id);
