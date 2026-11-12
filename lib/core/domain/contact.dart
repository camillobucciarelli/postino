import 'mailbox.dart';

/// Contatto (#216): a person suggested while writing a message, from the addresses seen in the synced mail.
/// Its address, lowercase, and its most recent display name, if any; written in a field with [formatMailbox].
typedef Contact = Mailbox;
