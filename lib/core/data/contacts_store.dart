import 'package:injectable/injectable.dart';

import '../domain/contact.dart';
import '../domain/contact_ranking.dart';
import '../domain/contacts_repository.dart';
import '../domain/platform_services.dart';
import 'postino_database.dart';

/// The Contatti from the messages in the local database (#216): no network, no state of their own to keep aligned.
@LazySingleton(as: ContactsRepository)
class ContactsStore(final PostinoDatabase _db, final Clock _clock) implements ContactsRepository {
  @override
  Future<List<Contact>> suggest(String prefix, {int limit = 6}) async {
    final p = prefix.trim();
    if (p.isEmpty) return const [];
    final dao = _db.contactsDao;
    final own = await dao.ownAddresses();
    final now = _clock.now();
    final rows = await dao.sightings(p);
    // Found by a word of the name: the messages to the bare address count too, and may carry a newer name. Only for
    // the best [limit] of them, which bounds the second query (one LIKE per address and column).
    final named = foundByName(rows.values, prefix: p, own: own, now: now);
    if (named.isNotEmpty) rows.addAll(await dao.sightingsOf(named.take(limit).toList()));
    return rankContacts(rows.values, prefix: p, own: own, now: now, limit: limit);
  }
}
