import 'contact.dart';

/// The Contatti suggested in A, Cc and Ccn (#216): from the mail of every Account, never from the Provider's address book.
abstract interface class ContactsRepository() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// The best [limit] Contatti whose address, or a word of whose name, starts with [prefix]; none for a blank one.
  Future<List<Contact>> suggest(String prefix, {int limit = 6});
}
